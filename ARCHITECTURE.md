# MegaApp — Architecture Reference

_Updated: 2026-03-27 — Target: iOS 18, SwiftUI, SwiftData_

---

## What This Is

A native iOS super-app merging two mini-apps into one shell:

- **Cartly** — grocery shopping, pantry management, AI meal planning, Kroger API integration
- **FitnessLog** — workout session tracking (treadmill, bike, outdoor run), GPS tracking, stats

The top navigation bar hosts an `AppSwitcher` (segmented control). Each mini-app has its own bottom `TabView` with its own tabs and color palette.

---

## Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9 |
| UI | SwiftUI (iOS 18, no UIKit except ShakeToRecoverModifier bridge) |
| Navigation | SwiftUI NavigationStack + TabView; no third-party routing |
| State | `@State` / `@Binding` in views; `@Observable` ViewModels in Cartly; `@ObservableObject` in Fitness services |
| Persistence | SwiftData (`@Model`, `@Query`, `ModelContainer`) |
| GPS | CoreLocation — `CLLocationManager` with background mode |
| TTS | `AVSpeechSynthesizer` |
| AI | OpenAI API via `URLSession` (actor isolation) |
| Kroger | Express proxy on `:3001` (existing Node server) |
| Charts | Swift Charts (iOS 16+) |

---

## Directory Structure

```
MegaApp/
├── project.yml                  ← XcodeGen config — run `xcodegen generate`
├── MegaApp.xcconfig             ← API keys (git-ignored)
├── MegaApp.xcconfig.template    ← Checked-in template
├── README.md
├── ARCHITECTURE.md
└── MegaApp/
    ├── App/
    │   ├── MegaAppApp.swift     ← @main, ModelContainer registration
    │   └── ContentView.swift    ← TopNavBar + AppSwitcher + conditional shell render
    │
    ├── Shared/
    │   ├── Theme.swift          ← Design tokens: Theme.Fitness.*, Theme.Cartly.*, Theme.Spacing.*
    │   ├── Persistence/
    │   │   ├── WorkoutSession.swift   ← @Model (cascade-deletes TreadmillSegment)
    │   │   ├── TreadmillSegment.swift ← included in WorkoutSession.swift
    │   │   ├── PantryItem.swift       ← @Model
    │   │   └── CartItem.swift         ← @Model
    │   └── Services/
    │       ├── OpenAIService.swift    ← actor; Whisper, chat completions, fence stripping
    │       └── InsightsEngine.swift   ← @MainActor @ObservableObject; rule-based + AI insights
    │
    ├── Fitness/
    │   ├── Models/
    │   │   ├── ActivityType.swift    ← enum ActivityType + ActivityFilter
    │   │   ├── SessionSnapshot.swift ← Sendable plain struct for undo / actor crossing
    │   │   └── SessionTemplate.swift ← 3 workout presets
    │   ├── Services/
    │   │   ├── OutdoorRunTracker.swift   ← @MainActor @ObservableObject; GPS + wall-clock timer + TTS
    │   │   └── RunRecoveryManager.swift  ← @MainActor @ObservableObject; 20s shake-to-undo
    │   ├── Utilities/
    │   │   ├── Format.swift                ← duration, pace, decimal, date helpers
    │   │   └── ShakeToRecoverModifier.swift ← UIKit UIViewControllerRepresentable bridge
    │   └── Views/
    │       ├── FitnessShell.swift      ← TabView owner; creates RunRecoveryManager
    │       ├── HistoryView.swift       ← @Query sessions + filter + swipe-delete + undo banner
    │       ├── SessionRow.swift        ← compact list row
    │       ├── SessionDetailView.swift ← read-only detail + Edit + Delete
    │       ├── SessionEditorView.swift ← create/edit form, treadmill segment builder, DurationField
    │       ├── StatsView.swift         ← Swift Charts: distance bars + pace line + PRs
    │       └── OutdoorRunView.swift    ← fullscreen live run modal; OutdoorRunTracker @StateObject
    │
    └── Cartly/
        ├── Models/
        │   └── CartlyModels.swift    ← KrogerProduct, KrogerStore structs
        ├── ViewModels/
        │   ├── PantryViewModel.swift  ← @Observable; voice recording → Whisper → GPT → toast
        │   ├── SearchViewModel.swift  ← @Observable; Kroger store + product search
        │   ├── PlanViewModel.swift    ← @Observable; GPT meal idea generation
        │   └── CartViewModel.swift    ← @Observable; macro totals, aisle grouping, mutations
        └── Views/
            ├── CartlyShell.swift      ← TabView owner; creates CartViewModel
            ├── PantryView.swift       ← @Query pantry + voice mic + approve toast
            ├── SearchView.swift       ← StorePickerSheet + product grid + ProductCard
            ├── PlanView.swift         ← 3-tier meal cards + MealDetailSheet bottom sheet
            ├── CartView.swift         ← Item list + macro bar + quantity controls
            └── AislesView.swift       ← Cart items grouped by Kroger aisle number
```

---

## Data Flow

### Fitness — session logging
```
SessionEditorView (form)
    └── .save() → WorkoutSession inserted → modelContext.save()
         └── @Query in HistoryView / StatsView automatically refreshes

OutdoorRunView
    └── OutdoorRunTracker.stop() → WorkoutSession inserted → modelContext.save()
```

### Fitness — shake-to-undo
```
HistoryView.deleteSession()
    ├── SessionSnapshot(from: session)    ← plain struct snapshot
    ├── recovery.registerDeleted(snapshot) ← starts 20s countdown
    └── modelContext.delete(session)

User shakes → HistoryView.onShake()
    └── recovery.recoverIfPossible(in: modelContext)
         └── snapshot.makeSession() → modelContext.insert() → save()
```

### GPS run tracking
```
CLLocationManager.didUpdateLocations
    → OutdoorRunTracker.processLocations(_:)
        ├── isValidFix check (accuracy ≤ 25m, age ≤ 120s, speed < 8 m/s)
        ├── Haversine distance accumulation
        ├── distanceMiles update (published → UI refresh)
        └── announceIfNeeded()   ← TTS triggered HERE, not from display timer
              └── AVSpeechSynthesizer.speak()

Timer (1s) → refreshDisplay()    ← elapsed string update only, NO distance/announcement
```

### Cartly — voice pantry update
```
PantryView mic button
    └── PantryViewModel.startRecording()
         └── AVAudioRecorder.record()

Mic button again (stop)
    └── PantryViewModel.stopAndProcess(context:items:)
         ├── AVAudioRecorder.stop()
         ├── OpenAIService.transcribe(audioData:)        [Whisper, temp N/A]
         ├── OpenAIService.parsePantryIntent(transcript:) [GPT-4o-mini, temp 0.1]
         └── showApproveToast = true  (20s countdown)

"Approve" button
    └── PantryViewModel.applyChanges(context:items:)
         └── add/update/remove PantryItems → modelContext.save()
```

### Insights
```
InsightsEngine.generate(sessions:pantryItems:)
    ├── ruleBasedInsights()   ← synchronous, always runs
    └── aiGeneratedInsights() ← async, 30-day rolling context window → GPT-4o-mini
```

---

## Critical Invariants (never change without updating CLAUDE.md)

| # | Rule | Why |
|---|---|---|
| 1 | Wall-clock timer only | Prevents elapsed drift in background |
| 2 | GPS announcements are location-driven | Calling them from the timer breaks cue accuracy |
| 3 | SwiftData for all persistence | No UserDefaults for structured data |
| 4 | Strip GPT JSON fences before parsing | GPT wraps JSON in ``` even when told not to |
| 5 | Voice pantry temp = 0.1 | Deterministic intent parsing |
| 6 | `SessionSnapshot` crosses actor boundaries | `@Model` objects are actor-isolated; plain structs are Sendable |

---

## Design System

`Theme.swift` provides two token namespaces:

| Token | Fitness | Cartly |
|---|---|---|
| `primaryAccent` | `#2563EB` (blue) | `#2ECC71` (green) |
| `background` | `#F5F7FA` (cool gray) | `#FFFFFF` |
| `cardBackground` | `#FFFFFF` | `#F8FAF8` |
| `textPrimary` | `#0F172A` | `#1A1A1A` |
| `textSecondary` | `#475569` | `#6B7280` |

Shared geometry: card radius 12pt, button radius 8pt, spacing scale 4/8/12/16/24/32.

---

## Kroger Proxy

The existing Express server (`mega-app/server/server.js`) runs on `:3001` and handles:
- `GET /stores?zip=...` → Kroger store list (or mock)
- `GET /products/search?query=...&locationId=...` → product search (or mock)

`SearchViewModel` calls `http://localhost:3001` via `URLSession`. If the proxy is unavailable it falls back to built-in mock data automatically so the UI remains functional.

**Future:** migrate to a serverless function (Cloudflare Workers or Vercel) to remove the local Node dependency.
