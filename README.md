# MegaApp — iOS 18 SwiftUI

A personal super-app combining **Cartly** (grocery/pantry + AI meal planning) and **FitnessLog** (workout tracking + GPS outdoor runs) in one native SwiftUI shell.

---

## Requirements

| Tool | Version |
|---|---|
| Xcode | 16.0+ |
| iOS target | 18.0 Simulator or device |
| Swift | 5.9 |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | 2.42+ |
| Node.js + npm | 18+ (for Kroger proxy) |

---

## Setup

### 1. Install XcodeGen

```bash
brew install xcodegen
```

### 2. Configure your OpenAI API key

```bash
cd /path/to/MegaApp
cp MegaApp.xcconfig.template MegaApp.xcconfig
# Edit MegaApp.xcconfig and replace `your_openai_api_key_here` with your real key
```

> ⚠️ `MegaApp.xcconfig` is git-ignored. Never commit it.

### 3. Generate the Xcode project

```bash
xcodegen generate
```

This creates `MegaApp.xcodeproj` in the current directory.

### 4. Open in Xcode

```bash
open MegaApp.xcodeproj
```

Select the **MegaApp** scheme → **iPhone 16 Simulator (iOS 18)** → Run.

### 5. Start the Kroger proxy (optional, for Search/Cart)

```bash
cd ../mega-app/server
npm install
npm start   # starts on :3001
```

Without the proxy running, Search falls back to mock product data automatically.

---

## GPS / Outdoor Run Setup

### Simulator
GPS does not work in the Simulator. The Outdoor Run screen will show "GPS Unavailable" — this is expected. Use a physical device for run tracking.

### Physical Device
1. In Xcode, sign the app with your personal team (Settings → Signing & Capabilities → Team).
2. On device, when prompted, grant location access as **"Always"** (not just "While Using").
3. Background location requires "Always" permission — the app explains this in the permission dialog.

> Background tasks do NOT work in Expo Go / development preview. For outdoor run testing on device, use `xcodegen generate && xcodebuild` (or just Run from Xcode).

---

## Architecture Overview

```
MegaApp/
├── App/                    ← @main entry + ContentView (TopNav + AppSwitcher)
├── Shared/
│   ├── Theme.swift         ← Design tokens for both shells
│   ├── Persistence/        ← SwiftData @Model classes
│   └── Services/           ← OpenAIService (actor), InsightsEngine
├── Fitness/                ← GPS run tracker, session history, stats
│   ├── Models/             ← ActivityType, SessionSnapshot, SessionTemplate
│   ├── Services/           ← OutdoorRunTracker, RunRecoveryManager
│   ├── Utilities/          ← Format helpers, ShakeToRecoverModifier
│   └── Views/
└── Cartly/                 ← Pantry, search, meal planning, cart
    ├── Models/             ← KrogerProduct, KrogerStore
    ├── ViewModels/         ← @Observable VMs for each tab
    └── Views/
```

---

## Key Design Decisions

### Wall-clock timer (Fitness)
`OutdoorRunTracker` computes elapsed time as `pausedAccumulatedSeconds + (now − runStartDate)` — never an incrementing counter. This prevents drift when the app is backgrounded or the timer fires late.

### Announcements are location-driven
Mile/half-mile TTS cues (`announceIfNeeded()`) are called from `processLocations(_:)`, not from the 1-second display timer. This is intentional — see CLAUDE.md.

### SwiftData for all persistence
`WorkoutSession`, `TreadmillSegment`, `PantryItem`, and `CartItem` are all `@Model` classes. No UserDefaults or FileManager for structured data.

### JSON fence stripping
`OpenAIService.stripFences(_:)` removes markdown code fences from GPT responses before `JSONDecoder`. Do not remove this — GPT wraps JSON even when instructed not to.

### Voice pantry temp = 0.1
The pantry intent parser uses `temperature: 0.1` for deterministic parsing. Do not raise it.

---

## Environment Variables

| Variable | File | Notes |
|---|---|---|
| `OPENAI_API_KEY` | `MegaApp.xcconfig` | Whisper + GPT-4o-mini. Injected into Info.plist at build time. |
| `KROGER_CLIENT_ID` | `mega-app/server/.env` | Kroger OAuth (proxy only) |
| `KROGER_CLIENT_SECRET` | `mega-app/server/.env` | Kroger OAuth — never commit |

---

## Known Limitations

- **GPS on Simulator** — CoreLocation returns mocked/no positions. Outdoor Run UI works but distance will be 0.
- **Voice recording on Simulator** — AVAudioRecorder works on physical devices. On Simulator, the mic may not be available.
- **Kroger Search/Cart** — requires the Express proxy on `:3001`. Auto-falls back to mock data when unavailable.
- **Insights AI calls** — require a valid OpenAI key. If the key is missing, rule-based insights still appear.
- **No push notifications** — `aps-environment` entitlement is not included. Add it if you want to send workout reminders.

---

## Roadmap / Future Work

- Migrate Express proxy to a serverless function (Cloudflare Workers or Vercel) to remove the Node dependency.
- Add HealthKit read/write for calorie and heart-rate sync.
- Add Widgets (WorkoutSummaryWidget, PantryStatusWidget) — the widget extension target stub is present in the original FitnessLog project.
- iCloud sync for SwiftData via `ModelContainer(isStoredInMemoryOnly: false)` + CloudKit entitlement.
