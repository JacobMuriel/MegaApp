import SwiftUI

// MARK: - Global design tokens
//
// Both mini-apps share the same font family (SF Pro / system default),
// corner radius language, and spacing scale. Each side has a distinct
// colour personality — blue/data-forward for Fitness, green/consumer for Cartly.
//
// Usage:
//   Theme.Fitness.primaryAccent    → Color
//   Theme.Spacing.md               → CGFloat
//   Theme.CornerRadius.card        → CGFloat

enum Theme {

    // MARK: Shared geometry

    enum CornerRadius {
        static let card:   CGFloat = 12
        static let button: CGFloat = 8
        static let chip:   CGFloat = 8
        static let large:  CGFloat = 20
    }

    enum Spacing {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 24
        static let xl:  CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: Fitness — clean, data-forward, premium blue palette

    enum Fitness {
        /// Strong blue — buttons, highlights, active tab indicator
        static let primaryAccent   = Color(hex: "2563EB")
        /// Darker blue — pressed states, secondary actions
        static let secondaryAccent = Color(hex: "1D4ED8")
        /// Cool light gray — screen background
        static let background      = Color(hex: "F5F7FA")
        /// White cards with subtle shadow
        static let cardBackground  = Color.white
        /// Near-black — primary body text
        static let textPrimary     = Color(hex: "0F172A")
        /// Slate — secondary labels, captions
        static let textSecondary   = Color(hex: "475569")
        static let danger          = Color(hex: "DC2626")
        static let success         = Color(hex: "16A34A")
        static let warning         = Color(hex: "D97706")
    }

    // MARK: Cartly — friendly, rounded, fresh green palette

    enum Cartly {
        /// Fresh green — buttons, highlights
        static let primaryAccent   = Color(hex: "2ECC71")
        /// Deeper green — pressed states, secondary actions
        static let secondaryAccent = Color(hex: "27AE60")
        /// White — screen background
        static let background      = Color.white
        /// Very light green-tinted card background
        static let cardBackground  = Color(hex: "F8FAF8")
        /// Near-black — primary text
        static let textPrimary     = Color(hex: "1A1A1A")
        /// Mid-gray — secondary labels
        static let textSecondary   = Color(hex: "6B7280")
        static let danger          = Color(hex: "C0392B")
        static let success         = Color(hex: "27AE60")
        static let warning         = Color(hex: "F39C12")
    }
}

// MARK: - Hex color initializer (shared utility)

extension Color {
    /// Initialise from a 6-digit hex string, with or without a leading `#`.
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = (int >> 16) & 0xFF
        let g = (int >> 8)  & 0xFF
        let b =  int        & 0xFF
        self.init(
            .sRGB,
            red:     Double(r) / 255,
            green:   Double(g) / 255,
            blue:    Double(b) / 255,
            opacity: 1
        )
    }
}

// MARK: - Shared card modifier

extension View {
    /// Standard card appearance used across both shells.
    func megaCard(background: Color = .white) -> some View {
        self
            .background(background, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.card))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}
