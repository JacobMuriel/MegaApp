import SwiftUI
import SwiftData

// MARK: - Editor mode

enum SessionEditorMode {
    case create(template: SessionTemplate?)
    case edit(WorkoutSession)
}

// MARK: - SessionEditorView
//
// Handles both creating a new session and editing an existing one.
// Layout mirrors the original FitnessLog SessionEditorView:
//   Basics → Activity-specific → Optional metrics → Rating/HR/Cal/Notes

struct SessionEditorView: View {
    let mode: SessionEditorMode

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    // MARK: Form state

    @State private var activityType:     ActivityType = .treadmill
    @State private var date:             Date         = Date()
    @State private var durationSeconds:  Int          = 30 * 60
    @State private var distanceMiles:    String       = ""
    @State private var avgSpeedMph:      String       = ""
    @State private var inclinePercent:   String       = ""
    @State private var avgWatts:         String       = ""
    @State private var avgHeartRateBpm:  String       = ""
    @State private var calories:         String       = ""
    @State private var rating:           Int          = 0
    @State private var notes:            String       = ""
    @State private var segments:         [SegmentDraft] = []
    @State private var showTemplatePicker = false

    var title: String {
        switch mode {
        case .create: return "New Session"
        case .edit:   return "Edit Session"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                basicsSection
                activitySection
                if activityType == .treadmill {
                    segmentSection
                }
                optionalMetricsSection
                ratingSection
                notesSection
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
                if case .create = mode {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Template") { showTemplatePicker = true }
                    }
                }
            }
            .sheet(isPresented: $showTemplatePicker) {
                TemplatePickerSheet { template in
                    applyTemplate(template)
                    showTemplatePicker = false
                }
            }
        }
        .onAppear { loadInitialState() }
    }

    // MARK: - Form sections

    private var basicsSection: some View {
        Section("Basics") {
            Picker("Activity", selection: $activityType) {
                ForEach(ActivityType.allCases) { t in
                    Label(t.displayName, systemImage: t.systemImage).tag(t)
                }
            }
            DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
            DurationField(label: "Duration", seconds: $durationSeconds)
        }
    }

    private var activitySection: some View {
        Section(activityType.displayName) {
            switch activityType {
            case .outdoorRun, .treadmill:
                LabeledTextField("Distance (mi)", text: $distanceMiles, keyboard: .decimalPad)
                LabeledTextField("Avg Speed (mph)", text: $avgSpeedMph, keyboard: .decimalPad)
                if activityType == .treadmill {
                    LabeledTextField("Incline (%)", text: $inclinePercent, keyboard: .decimalPad)
                }
            case .bike:
                LabeledTextField("Avg Watts", text: $avgWatts, keyboard: .numberPad)
                LabeledTextField("Distance (mi)", text: $distanceMiles, keyboard: .decimalPad)
            }
        }
    }

    private var segmentSection: some View {
        Section("Treadmill Segments") {
            ForEach(segments.indices, id: \.self) { i in
                SegmentRow(draft: $segments[i])
            }
            .onDelete { offsets in segments.remove(atOffsets: offsets) }
            .onMove  { from, to  in segments.move(fromOffsets: from, toOffset: to) }

            Button {
                segments.append(SegmentDraft(speedMph: 5.0, durationSeconds: 5 * 60))
            } label: {
                Label("Add Segment", systemImage: "plus")
                    .foregroundStyle(Theme.Fitness.primaryAccent)
            }
        }
    }

    private var optionalMetricsSection: some View {
        Section("Optional Metrics") {
            LabeledTextField("Avg HR (bpm)", text: $avgHeartRateBpm, keyboard: .numberPad)
            LabeledTextField("Calories", text: $calories, keyboard: .numberPad)
        }
    }

    private var ratingSection: some View {
        Section("Effort Rating (0–10)") {
            HStack {
                Text("\(rating)")
                    .font(.headline.monospacedDigit())
                    .frame(width: 28)
                Slider(value: Binding(
                    get:  { Double(rating) },
                    set:  { rating = Int($0) }
                ), in: 0...10, step: 1)
                .tint(Theme.Fitness.primaryAccent)
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextEditor(text: $notes)
                .frame(minHeight: 80)
        }
    }

    // MARK: - Load / apply

    private func loadInitialState() {
        switch mode {
        case .create(let template):
            if let t = template { applyTemplate(t) }
        case .edit(let session):
            activityType     = session.activityTypeEnum
            date             = session.date
            durationSeconds  = session.durationSeconds
            distanceMiles    = session.distanceMiles.map    { Format.decimal($0, places: 2) } ?? ""
            avgSpeedMph      = session.avgSpeedMph.map      { Format.decimal($0, places: 1) } ?? ""
            inclinePercent   = session.inclinePercent.map   { Format.decimal($0, places: 1) } ?? ""
            avgWatts         = session.avgWatts.map         { "\($0)" } ?? ""
            avgHeartRateBpm  = session.avgHeartRateBpm.map  { "\($0)" } ?? ""
            calories         = session.calories.map         { "\($0)" } ?? ""
            rating           = session.rating ?? 0
            notes            = session.notes ?? ""
            segments         = session.segments
                .sorted { $0.sortOrder < $1.sortOrder }
                .map    { SegmentDraft(speedMph: $0.speedMph, durationSeconds: $0.durationSeconds) }
        }
    }

    private func applyTemplate(_ template: SessionTemplate) {
        activityType    = template.activityType
        durationSeconds = template.defaultDurationSeconds
        distanceMiles   = template.defaultDistanceMiles.map { Format.decimal($0, places: 2) } ?? ""
        avgSpeedMph     = template.defaultSpeedMph.map      { Format.decimal($0, places: 1) } ?? ""
        inclinePercent  = template.defaultIncline.map       { Format.decimal($0, places: 1) } ?? ""
        avgWatts        = template.defaultWatts.map         { "\($0)" } ?? ""
        segments        = template.defaultSegments.map { SegmentDraft(speedMph: $0.speedMph, durationSeconds: $0.durationSeconds) }
    }

    // MARK: - Save

    private func save() {
        switch mode {
        case .create:
            let session = buildSession()
            modelContext.insert(session)
        case .edit(let session):
            applyEdits(to: session)
        }
        try? modelContext.save()
        dismiss()
    }

    private func buildSession() -> WorkoutSession {
        let session = WorkoutSession(
            activityType:    activityType.rawValue,
            durationSeconds: durationSeconds,
            distanceMiles:   Double(distanceMiles),
            calories:        Int(calories),
            avgHeartRateBpm: Int(avgHeartRateBpm),
            rating:          rating > 0 ? rating : nil,
            inclinePercent:  Double(inclinePercent),
            avgSpeedMph:     Double(avgSpeedMph),
            avgWatts:        Int(avgWatts),
            notes:           notes.isEmpty ? nil : notes
        )
        session.date     = date
        session.segments = segments.enumerated().map { idx, draft in
            TreadmillSegment(speedMph: draft.speedMph, durationSeconds: draft.durationSeconds, sortOrder: idx)
        }
        return session
    }

    private func applyEdits(to session: WorkoutSession) {
        session.activityType    = activityType.rawValue
        session.date            = date
        session.durationSeconds = durationSeconds
        session.distanceMiles   = Double(distanceMiles)
        session.calories        = Int(calories)
        session.avgHeartRateBpm = Int(avgHeartRateBpm)
        session.rating          = rating > 0 ? rating : nil
        session.inclinePercent  = Double(inclinePercent)
        session.avgSpeedMph     = Double(avgSpeedMph)
        session.avgWatts        = Int(avgWatts)
        session.notes           = notes.isEmpty ? nil : notes

        // Replace segments entirely — simpler than diffing
        for seg in session.segments { modelContext.delete(seg) }
        session.segments = segments.enumerated().map { idx, draft in
            TreadmillSegment(speedMph: draft.speedMph, durationSeconds: draft.durationSeconds, sortOrder: idx)
        }
    }
}

// MARK: - SegmentDraft (transient form model)

struct SegmentDraft: Identifiable {
    let id = UUID()
    var speedMph:        Double
    var durationSeconds: Int
}

// MARK: - SegmentRow

private struct SegmentRow: View {
    @Binding var draft: SegmentDraft

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Speed stepper
            HStack(spacing: 4) {
                Button { draft.speedMph = max(1.0, draft.speedMph - 0.5) } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(Theme.Fitness.primaryAccent)
                }
                Text(Format.decimal(draft.speedMph, places: 1) + " mph")
                    .font(.subheadline.monospacedDigit())
                    .frame(minWidth: 68)
                Button { draft.speedMph = min(20.0, draft.speedMph + 0.5) } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.Fitness.primaryAccent)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Duration field
            DurationField(label: "dur", seconds: Binding(
                get: { draft.durationSeconds },
                set: { draft.durationSeconds = $0 }
            ))
        }
    }
}

// MARK: - DurationField
//
// Displays mm:ss with two text fields. Changes are committed on each keystroke.
// The `label` is used for accessibility only.

struct DurationField: View {
    let label: String
    @Binding var seconds: Int

    @State private var minutesStr: String = "0"
    @State private var secondsStr: String = "00"

    var body: some View {
        HStack(spacing: 4) {
            TextField("min", text: $minutesStr)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 44)
                .accessibilityLabel("\(label) minutes")
            Text(":")
                .foregroundStyle(.secondary)
            TextField("sec", text: $secondsStr)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.leading)
                .frame(width: 36)
                .accessibilityLabel("\(label) seconds")
        }
        .onAppear { syncFromSeconds() }
        .onChange(of: seconds)    { _, _ in syncFromSeconds() }
        .onChange(of: minutesStr) { _, _ in syncToSeconds()   }
        .onChange(of: secondsStr) { _, _ in syncToSeconds()   }
    }

    private func syncFromSeconds() {
        // Only update if the displayed value would change, to avoid cursor-jump
        let m = "\(seconds / 60)"
        let s = String(format: "%02d", seconds % 60)
        if minutesStr != m { minutesStr = m }
        if secondsStr != s { secondsStr = s }
    }

    private func syncToSeconds() {
        let mins = Int(minutesStr) ?? 0
        let secs = min(59, Int(secondsStr) ?? 0)
        seconds  = mins * 60 + secs
    }
}

// MARK: - LabeledTextField

private struct LabeledTextField: View {
    let label:    String
    @Binding var text: String
    let keyboard: UIKeyboardType

    init(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) {
        self.label    = label
        self._text    = text
        self.keyboard = keyboard
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("–", text: $text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Theme.Fitness.textPrimary)
        }
    }
}

// MARK: - TemplatePickerSheet

private struct TemplatePickerSheet: View {
    let onSelect: (SessionTemplate) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(SessionTemplate.allCases) { template in
                Button {
                    onSelect(template)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.rawValue)
                            .font(.headline)
                            .foregroundStyle(Theme.Fitness.textPrimary)
                        Text(Format.duration(template.defaultDurationSeconds))
                            .font(.subheadline)
                            .foregroundStyle(Theme.Fitness.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Choose Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
