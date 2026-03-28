import SwiftUI
import SwiftData
import CoreLocation

// MARK: - OutdoorRunView
//
// Full-screen modal presented during an active outdoor run.
// Uses OutdoorRunTracker (@StateObject) for all GPS/timing logic.
//
// Button state machine:
//   idle    → [Start]
//   running → [Pause]  [Stop]
//   paused  → [Resume] [Stop]
//
// On Stop: creates a WorkoutSession and inserts it into SwiftData.

struct OutdoorRunView: View {
    @StateObject private var tracker = OutdoorRunTracker()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    @State private var showPermissionAlert = false
    @State private var showDiscardAlert    = false

    var body: some View {
        ZStack {
            Theme.Fitness.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Dismiss / header
                header

                Spacer()

                // Live metrics
                metricsDisplay

                Spacer()

                // Control buttons
                controlButtons
                    .padding(.bottom, 48)
            }
        }
        .onAppear {
            tracker.requestPermission()
        }
        .onChange(of: tracker.locationAuthStatus) { _, status in
            if status == .denied || status == .restricted {
                showPermissionAlert = true
            }
        }
        .alert("Location Access Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { dismiss() }
        } message: {
            Text("MegaApp needs location access set to 'Always' to track outdoor runs in the background. Please update this in Settings.")
        }
        .alert("Discard Run?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep Going", role: .cancel) { }
        } message: {
            Text("Your current run progress will be lost.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            if tracker.status == .idle {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.Fitness.textSecondary)
                        .padding(10)
                        .background(Color(.systemGray5), in: Circle())
                }
            } else {
                // During a run, close button requires confirmation
                Button {
                    showDiscardAlert = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.Fitness.textSecondary)
                        .padding(10)
                        .background(Color(.systemGray5), in: Circle())
                }
            }
            Spacer()
            Text("Outdoor Run")
                .font(.headline)
                .foregroundStyle(Theme.Fitness.textPrimary)
            Spacer()
            // Balance the layout
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.md)
    }

    // MARK: - Live metrics

    private var metricsDisplay: some View {
        VStack(spacing: Theme.Spacing.xl) {
            // Elapsed time — largest display element
            VStack(spacing: 4) {
                Text(tracker.displayElapsed)
                    .font(.system(size: 72, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.Fitness.textPrimary)
                    .contentTransition(.numericText())
                Text("elapsed")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Fitness.textSecondary)
            }

            // Distance + pace side by side
            HStack(spacing: Theme.Spacing.xl) {
                BigMetric(
                    label: "DISTANCE",
                    value: Format.decimal(tracker.distanceMiles, places: 2),
                    unit: "mi"
                )
                BigMetric(
                    label: "PACE",
                    value: tracker.currentPaceString,
                    unit: ""
                )
            }

            // GPS status indicator
            GPSStatusIndicator(status: tracker.locationAuthStatus)
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    // MARK: - Control buttons

    @ViewBuilder
    private var controlButtons: some View {
        switch tracker.status {
        case .idle:
            RunButton(label: "Start", color: Theme.Fitness.primaryAccent, icon: "figure.run") {
                tracker.start()
            }

        case .running:
            HStack(spacing: Theme.Spacing.xl) {
                RunButton(label: "Pause", color: Theme.Fitness.warning, icon: "pause.fill") {
                    tracker.pause()
                }
                RunButton(label: "Stop", color: Theme.Fitness.danger, icon: "stop.fill") {
                    finishRun()
                }
            }

        case .paused:
            HStack(spacing: Theme.Spacing.xl) {
                RunButton(label: "Resume", color: Theme.Fitness.primaryAccent, icon: "play.fill") {
                    tracker.resume()
                }
                RunButton(label: "Stop", color: Theme.Fitness.danger, icon: "stop.fill") {
                    finishRun()
                }
            }
        }
    }

    // MARK: - Finish run

    private func finishRun() {
        let (duration, distance) = tracker.stop()
        guard duration > 0 else {
            dismiss()
            return
        }
        let session = WorkoutSession(
            activityType:    ActivityType.outdoorRun.rawValue,
            durationSeconds: duration,
            distanceMiles:   distance > 0 ? distance : nil
        )
        modelContext.insert(session)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - BigMetric

private struct BigMetric: View {
    let label: String
    let value: String
    let unit:  String

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.Fitness.textSecondary)
                .tracking(1)
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.Fitness.textPrimary)
                .contentTransition(.numericText())
            if !unit.isEmpty {
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(Theme.Fitness.textSecondary)
            }
        }
    }
}

// MARK: - RunButton

private struct RunButton: View {
    let label:  String
    let color:  Color
    let icon:   String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 72, height: 72)
                        .shadow(color: color.opacity(0.4), radius: 10, x: 0, y: 4)
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Fitness.textPrimary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - GPS status indicator

private struct GPSStatusIndicator: View {
    let status: CLAuthorizationStatus

    private var color: Color {
        switch status {
        case .authorizedAlways:   return Theme.Fitness.success
        case .authorizedWhenInUse: return Theme.Fitness.warning
        default:                  return Theme.Fitness.danger
        }
    }

    private var label: String {
        switch status {
        case .authorizedAlways:   return "GPS Ready"
        case .authorizedWhenInUse: return "GPS — background limited"
        case .notDetermined:      return "Requesting GPS…"
        default:                  return "GPS Unavailable"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.Fitness.textSecondary)
        }
    }
}
