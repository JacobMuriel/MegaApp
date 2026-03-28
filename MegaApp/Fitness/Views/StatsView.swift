import SwiftUI
import SwiftData
import Charts

// MARK: - StatsView
//
// Two Swift Charts (iOS 16+):
//   • Distance per session (bar chart, tappable)
//   • Pace trend (line chart, all runs — outdoor + treadmill)
// Runs/Bike toggle at top separates the two activity groups.
// A segmented picker controls the window size (last 5 / 10 / 20 / 50 sessions).

struct StatsView: View {
    @Query(sort: \WorkoutSession.date, order: .forward) private var allSessions: [WorkoutSession]

    @State private var windowSize: Int = 20
    @State private var chartMode: ChartMode = .runs
    @State private var selectedBarIndex: Int? = nil

    enum ChartMode: String, CaseIterable {
        case runs = "Runs"
        case bike = "Bike"
    }

    // MARK: Derived data

    // Outdoor runs + treadmill sessions with distance
    private var runSessions: [WorkoutSession] {
        allSessions
            .filter {
                ($0.activityType == ActivityType.outdoorRun.rawValue ||
                 $0.activityType == ActivityType.treadmill.rawValue)
                && $0.distanceMiles != nil && $0.durationSeconds > 0
            }
            .suffix(windowSize)
    }

    // Bike sessions with distance
    private var bikeSessions: [WorkoutSession] {
        allSessions
            .filter { $0.activityType == ActivityType.bike.rawValue && $0.distanceMiles != nil && $0.durationSeconds > 0 }
            .suffix(windowSize)
    }

    private var activeSessions: [WorkoutSession] {
        chartMode == .runs ? runSessions : bikeSessions
    }

    // All runs (outdoor + treadmill) with pace — used for pace trend chart
    private var paceSessions: [WorkoutSession] {
        allSessions
            .filter {
                ($0.activityType == ActivityType.outdoorRun.rawValue ||
                 $0.activityType == ActivityType.treadmill.rawValue)
                && $0.paceMinPerMile != nil
            }
            .suffix(windowSize)
    }

    // MARK: Personal records (runs and bike kept separate)

    private var longestRun: WorkoutSession? {
        allSessions
            .filter {
                $0.activityType == ActivityType.outdoorRun.rawValue ||
                $0.activityType == ActivityType.treadmill.rawValue
            }
            .max { ($0.distanceMiles ?? 0) < ($1.distanceMiles ?? 0) }
    }

    private var fastestPace: WorkoutSession? {
        allSessions
            .filter {
                ($0.activityType == ActivityType.outdoorRun.rawValue ||
                 $0.activityType == ActivityType.treadmill.rawValue)
                && $0.paceMinPerMile != nil
            }
            .min { ($0.paceMinPerMile ?? 99) < ($1.paceMinPerMile ?? 99) }
    }

    private var longestBike: WorkoutSession? {
        allSessions
            .filter { $0.activityType == ActivityType.bike.rawValue }
            .max    { $0.durationSeconds < $1.durationSeconds }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {

                // Runs / Bike toggle
                Picker("Activity", selection: $chartMode) {
                    ForEach(ChartMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.Spacing.md)
                .onChange(of: chartMode) { _, _ in selectedBarIndex = nil }

                // Window picker
                Picker("Last", selection: $windowSize) {
                    Text("5").tag(5)
                    Text("10").tag(10)
                    Text("20").tag(20)
                    Text("50").tag(50)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.Spacing.md)
                .onChange(of: windowSize) { _, _ in selectedBarIndex = nil }

                // Distance chart
                if !activeSessions.isEmpty {
                    distanceChart
                }

                // Pace chart — all runs (outdoor + treadmill), not shown for bike
                if chartMode == .runs && paceSessions.count >= 2 {
                    paceChart
                }

                // Personal records
                personalRecordsSection

                // Activity counts
                activityCountsSection
            }
            .padding(.vertical, Theme.Spacing.md)
        }
        .background(Theme.Fitness.background.ignoresSafeArea())
        .navigationTitle("Stats")
    }

    // MARK: - Distance chart (tappable bars)

    private var distanceChart: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Distance per Session")
                .font(.headline)
                .foregroundStyle(Theme.Fitness.textPrimary)
                .padding(.horizontal, Theme.Spacing.md)

            Chart(Array(activeSessions.enumerated()), id: \.offset) { idx, session in
                BarMark(
                    x: .value("Session", idx + 1),
                    y: .value("Miles", session.distanceMiles ?? 0)
                )
                .foregroundStyle(barColor(for: session))
                .cornerRadius(4)
                .annotation(position: .top, alignment: .center) {
                    if selectedBarIndex == idx, let dist = session.distanceMiles {
                        Text(Format.decimal(dist, places: 2) + " mi")
                            .font(.caption2.bold())
                            .foregroundStyle(Theme.Fitness.primaryAccent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 4))
                            .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)
                    }
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading) { val in
                    AxisGridLine()
                    AxisValueLabel { Text(Format.decimal(val.as(Double.self) ?? 0, places: 1) + " mi").font(.caption) }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let x = value.location.x - geo[proxy.plotFrame].origin.x
                                    if let barNum: Int = proxy.value(atX: x) {
                                        let idx = max(0, min(activeSessions.count - 1, barNum - 1))
                                        selectedBarIndex = idx
                                    }
                                }
                                .onEnded { _ in selectedBarIndex = nil }
                        )
                }
            }
            .frame(height: 180)
            .padding(.horizontal, Theme.Spacing.md)
        }
        .padding(.vertical, Theme.Spacing.md)
        .megaCard(background: Theme.Fitness.cardBackground)
        .padding(.horizontal, Theme.Spacing.md)
    }

    private func barColor(for session: WorkoutSession) -> Color {
        switch chartMode {
        case .runs:
            // Outdoor runs: full opacity; treadmill: slightly faded
            return session.activityType == ActivityType.outdoorRun.rawValue
                ? Theme.Fitness.primaryAccent
                : Theme.Fitness.primaryAccent.opacity(0.55)
        case .bike:
            return Theme.Fitness.secondaryAccent
        }
    }

    // MARK: - Pace chart (all runs)

    private var paceChart: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Pace Trend (All Runs)")
                .font(.headline)
                .foregroundStyle(Theme.Fitness.textPrimary)
                .padding(.horizontal, Theme.Spacing.md)

            Chart(Array(paceSessions.enumerated()), id: \.offset) { idx, session in
                if let pace = session.paceMinPerMile {
                    LineMark(
                        x: .value("Run", idx + 1),
                        y: .value("min/mi", pace)
                    )
                    .foregroundStyle(Theme.Fitness.secondaryAccent)

                    PointMark(
                        x: .value("Run", idx + 1),
                        y: .value("min/mi", pace)
                    )
                    .foregroundStyle(
                        session.activityType == ActivityType.outdoorRun.rawValue
                            ? Theme.Fitness.primaryAccent
                            : Theme.Fitness.primaryAccent.opacity(0.55)
                    )
                    .symbolSize(30)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading) { val in
                    AxisGridLine()
                    AxisValueLabel {
                        if let d = val.as(Double.self) {
                            Text(Format.pace(d)).font(.caption)
                        }
                    }
                }
            }
            // Inverted Y: lower pace = faster, so smaller values appear higher
            .chartYScale(domain: .automatic(reversed: true))
            .frame(height: 160)
            .padding(.horizontal, Theme.Spacing.md)
        }
        .padding(.vertical, Theme.Spacing.md)
        .megaCard(background: Theme.Fitness.cardBackground)
        .padding(.horizontal, Theme.Spacing.md)
    }

    // MARK: - Personal records

    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Personal Records")
                .font(.headline)
                .foregroundStyle(Theme.Fitness.textPrimary)

            if let s = longestRun, let dist = s.distanceMiles {
                PRRow(label: "Longest Run",
                      value: Format.decimal(dist, places: 2) + " mi",
                      date: s.date)
            }
            if let s = fastestPace, let pace = s.paceMinPerMile {
                PRRow(label: "Fastest Mile Pace",
                      value: Format.pace(pace),
                      date: s.date)
            }
            if let s = longestBike {
                PRRow(label: "Longest Bike Session",
                      value: Format.duration(s.durationSeconds),
                      date: s.date)
            }
            if longestRun == nil && fastestPace == nil && longestBike == nil {
                Text("Log some sessions to see your records here.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Fitness.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .megaCard(background: Theme.Fitness.cardBackground)
        .padding(.horizontal, Theme.Spacing.md)
    }

    // MARK: - Activity counts

    private var activityCountsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("All Time")
                .font(.headline)
                .foregroundStyle(Theme.Fitness.textPrimary)

            HStack(spacing: Theme.Spacing.sm) {
                ForEach(ActivityType.allCases) { type in
                    let count = allSessions.filter { $0.activityType == type.rawValue }.count
                    VStack(spacing: 4) {
                        Image(systemName: type.systemImage)
                            .foregroundStyle(Theme.Fitness.primaryAccent)
                        Text("\(count)")
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(Theme.Fitness.textPrimary)
                        Text(type.displayName)
                            .font(.caption)
                            .foregroundStyle(Theme.Fitness.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(Theme.Spacing.sm)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: Theme.CornerRadius.button))
                }
            }
        }
        .padding(Theme.Spacing.md)
        .megaCard(background: Theme.Fitness.cardBackground)
        .padding(.horizontal, Theme.Spacing.md)
    }
}

// MARK: - PRRow

private struct PRRow: View {
    let label: String
    let value: String
    let date:  Date

    var body: some View {
        HStack {
            Image(systemName: "trophy.fill")
                .foregroundStyle(.yellow)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Fitness.textSecondary)
                Text(Format.dateShort(date))
                    .font(.caption)
                    .foregroundStyle(Theme.Fitness.textSecondary)
            }
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.Fitness.textPrimary)
        }
        .padding(.vertical, 2)
    }
}
