import SwiftUI

// MARK: - SessionRow
//
// Compact list row shown in HistoryView. Displays:
//   • Activity icon + type
//   • Date + duration
//   • Primary metric (pace for runs, speed for treadmill, watts for bike)
//   • Star rating dot strip and calorie count

struct SessionRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Activity icon badge
            ZStack {
                Circle()
                    .fill(Theme.Fitness.primaryAccent.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: session.activityTypeEnum.systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.Fitness.primaryAccent)
            }

            // Center: type only (date is already the section header)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.activityTypeEnum.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Fitness.textPrimary)
                // Optional rating dots
                if let rating = session.rating, rating > 0 {
                    RatingDots(rating: rating)
                        .padding(.top, 1)
                }
            }

            Spacer()

            // Right: time → distance → calories
            VStack(alignment: .trailing, spacing: 2) {
                Text(Format.duration(session.durationSeconds))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.Fitness.textPrimary)

                if let dist = session.distanceMiles {
                    Text(Format.decimal(dist, places: 2) + " mi")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.Fitness.textSecondary)
                }
                if let cal = session.calories {
                    Text("\(cal) kcal")
                        .font(.caption)
                        .foregroundStyle(Theme.Fitness.textSecondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

}

// MARK: - Rating dot strip

private struct RatingDots: View {
    let rating: Int   // 0–10

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...10, id: \.self) { i in
                Circle()
                    .fill(i <= rating ? Theme.Fitness.primaryAccent : Color(.systemGray5))
                    .frame(width: 5, height: 5)
            }
        }
    }
}

#Preview {
    List {
        SessionRow(session: WorkoutSession(
            activityType:    "outdoorRun",
            durationSeconds: 1925,
            distanceMiles:   3.1,
            calories:        312,
            rating:          8
        ))
        SessionRow(session: WorkoutSession(
            activityType:    "treadmill",
            durationSeconds: 1800,
            distanceMiles:   2.5,
            avgSpeedMph:     5.0
        ))
        SessionRow(session: WorkoutSession(
            activityType:    "bike",
            durationSeconds: 2700,
            calories:        410,
            avgWatts:        185
        ))
    }
}
