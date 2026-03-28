import SwiftUI
import SwiftData

// MARK: - HistoryView

struct HistoryView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var allSessions: [WorkoutSession]
    @Environment(\.modelContext) private var modelContext

    @ObservedObject var recovery: RunRecoveryManager

    @State private var filter:           ActivityFilter = .all
    @State private var showEditor        = false
    @State private var showOutdoorRun    = false
    @State private var selectedTemplate: SessionTemplate? = nil
    @State private var importAlertMessage: String?       = nil

    // MARK: Filtered data

    private var sessions: [WorkoutSession] {
        guard let rawValue = filter.activityTypeRawValue else { return allSessions }
        return allSessions.filter { $0.activityType == rawValue }
    }

    /// Sessions grouped by calendar day, descending.
    private var groupedSessions: [(day: Date, sessions: [WorkoutSession])] {
        let calendar = Calendar.current
        let groups   = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.date) }
        return groups.sorted { $0.key > $1.key }.map { (day: $0.key, sessions: $0.value) }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Activity filter chips
                filterPicker
                    .padding(.vertical, Theme.Spacing.sm)

                if sessions.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }

            // Shake-to-undo recovery banner
            if recovery.isPending {
                recoveryBanner
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.sm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("Workout History")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showOutdoorRun = true
                } label: {
                    Label("Outdoor Run", systemImage: "figure.run")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    selectedTemplate = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    runImport()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            SessionEditorView(mode: .create(template: selectedTemplate))
        }
        .fullScreenCover(isPresented: $showOutdoorRun) {
            OutdoorRunView()
        }
        // Shake anywhere in the history screen triggers undo
        .onShake {
            withAnimation {
                _ = recovery.recoverIfPossible(in: modelContext)
            }
        }
        .alert("Import Sessions", isPresented: .init(
            get: { importAlertMessage != nil },
            set: { if !$0 { importAlertMessage = nil } }
        )) {
            Button("OK") { importAlertMessage = nil }
        } message: {
            Text(importAlertMessage ?? "")
        }
    }

    // MARK: - Subviews

    private var filterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(ActivityFilter.allCases) { f in
                    FilterChip(title: f.rawValue, isSelected: filter == f) {
                        filter = f
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
    }

    private var sessionList: some View {
        List {
            ForEach(groupedSessions, id: \.day) { group in
                Section(header: Text(Format.relativeDayHeader(group.day))) {
                    ForEach(group.sessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session, recovery: recovery)
                        } label: {
                            SessionRow(session: session)
                        }
                    }
                    .onDelete { offsets in
                        deleteSession(at: offsets, in: group.sessions)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.default, value: filter)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 52))
                .foregroundStyle(Theme.Fitness.textSecondary)
            Text("No sessions yet")
                .font(.headline)
                .foregroundStyle(Theme.Fitness.textSecondary)
            Text("Tap + to log a workout or start an outdoor run.")
                .font(.subheadline)
                .foregroundStyle(Theme.Fitness.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var recoveryBanner: some View {
        HStack {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .foregroundStyle(Theme.Fitness.primaryAccent)
            Text("Session deleted — shake to undo (\(recovery.secondsRemaining)s)")
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
            Button("Undo") {
                withAnimation {
                    _ = recovery.recoverIfPossible(in: modelContext)
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.Fitness.primaryAccent)
        }
        .padding(Theme.Spacing.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.card))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }

    // MARK: - Import

    private func runImport() {
        do {
            let result = try DataImportService.importFromBundle(into: modelContext)
            if result.inserted == 0 {
                importAlertMessage = "Already up to date — \(result.skipped) session\(result.skipped == 1 ? "" : "s") already imported."
            } else {
                importAlertMessage = "Imported \(result.inserted) session\(result.inserted == 1 ? "" : "s")."
                    + (result.skipped > 0 ? " \(result.skipped) skipped (duplicates)." : "")
            }
        } catch {
            importAlertMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Delete

    private func deleteSession(at offsets: IndexSet, in group: [WorkoutSession]) {
        for idx in offsets {
            let session  = group[idx]
            let snapshot = SessionSnapshot(from: session)
            recovery.registerDeleted(snapshot: snapshot)
            modelContext.delete(session)
        }
        try? modelContext.save()
    }
}

// MARK: - FilterChip

private struct FilterChip: View {
    let title:      String
    let isSelected: Bool
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : Theme.Fitness.textPrimary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs + 2)
                .background(
                    isSelected ? Theme.Fitness.primaryAccent : Color(.systemGray5),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
