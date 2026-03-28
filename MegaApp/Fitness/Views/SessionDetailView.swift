import SwiftUI
import SwiftData

// MARK: - SessionDetailView
//
// Read-only detail view for a session. All fields are displayed; fields that
// are nil are simply omitted. Provides Edit (sheet) and Delete (destructive) actions.

struct SessionDetailView: View {
    @Bindable var session:  WorkoutSession
    @ObservedObject var recovery: RunRecoveryManager

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    @State private var showEditor     = false
    @State private var showDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                headerCard
                metricsGrid
                if session.activityTypeEnum == .treadmill && !session.segments.isEmpty {
                    segmentsSection
                }
                if let notes = session.notes, !notes.isEmpty {
                    notesSection(notes)
                }
                deleteButton
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Fitness.background.ignoresSafeArea())
        .navigationTitle(session.activityTypeEnum.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { showEditor = true }
                    .foregroundStyle(Theme.Fitness.primaryAccent)
            }
        }
        .sheet(isPresented: $showEditor) {
            SessionEditorView(mode: .edit(session))
        }
        .alert("Delete Session?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { deleteSession() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This can be undone by shaking your device within 20 seconds.")
        }
    }

    // MARK: - Header card

    private var headerCard: some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Theme.Fitness.primaryAccent.opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: session.activityTypeEnum.systemImage)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Theme.Fitness.primaryAccent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(session.activityTypeEnum.displayName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.Fitness.textPrimary)
                Text(Format.date(session.date))
                    .font(.subheadline)
                    .foregroundStyle(Theme.Fitness.textSecondary)
                if let rating = session.rating, rating > 0 {
                    HStack(spacing: 2) {
                        ForEach(1...10, id: \.self) { i in
                            Image(systemName: i <= rating ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundStyle(i <= rating ? Theme.Fitness.primaryAccent : Color(.systemGray4))
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .megaCard(background: Theme.Fitness.cardBackground)
    }

    // MARK: - Metrics grid

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
            MetricCell(label: "Duration",  value: Format.duration(session.durationSeconds))

            if let dist = session.distanceMiles {
                MetricCell(label: "Distance", value: Format.decimal(dist, places: 2) + " mi")
            }
            if let pace = session.paceMinPerMile {
                MetricCell(label: "Avg Pace", value: Format.pace(pace))
            }
            if let spd = session.computedAvgSpeedMph, session.activityTypeEnum == .treadmill {
                MetricCell(label: "Avg Speed", value: Format.decimal(spd, places: 1) + " mph")
            }
            if let watts = session.avgWatts {
                MetricCell(label: "Avg Watts", value: "\(watts) W")
            }
            if let hr = session.avgHeartRateBpm {
                MetricCell(label: "Avg HR", value: "\(hr) bpm")
            }
            if let cal = session.calories {
                MetricCell(label: "Calories", value: "\(cal) kcal")
            }
            if let incline = session.inclinePercent {
                MetricCell(label: "Incline", value: Format.decimal(incline, places: 1) + "%")
            }
        }
    }

    // MARK: - Treadmill segments

    private var segmentsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Segments")
                .font(.headline)
                .foregroundStyle(Theme.Fitness.textPrimary)

            ForEach(session.segments.sorted(by: { $0.sortOrder < $1.sortOrder })) { seg in
                HStack {
                    Text(Format.decimal(seg.speedMph, places: 1) + " mph")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.Fitness.textPrimary)
                    Spacer()
                    Text(Format.duration(seg.durationSeconds))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Theme.Fitness.textSecondary)
                    Text("→ " + Format.decimal(seg.distanceMiles, places: 2) + " mi")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.Fitness.textSecondary)
                }
                .padding(.vertical, 6)
                Divider()
            }
        }
        .padding(Theme.Spacing.md)
        .megaCard(background: Theme.Fitness.cardBackground)
    }

    // MARK: - Notes

    private func notesSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Notes")
                .font(.headline)
                .foregroundStyle(Theme.Fitness.textPrimary)
            Text(text)
                .font(.body)
                .foregroundStyle(Theme.Fitness.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .megaCard(background: Theme.Fitness.cardBackground)
    }

    // MARK: - Delete button

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteAlert = true
        } label: {
            Label("Delete Session", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(Theme.Fitness.danger)
        .padding(.top, Theme.Spacing.sm)
    }

    // MARK: - Delete action

    private func deleteSession() {
        let snapshot = SessionSnapshot(from: session)
        recovery.registerDeleted(snapshot: snapshot)
        modelContext.delete(session)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - MetricCell

private struct MetricCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.Fitness.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.Fitness.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
        .megaCard(background: Theme.Fitness.cardBackground)
    }
}
