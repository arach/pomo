import SwiftUI

/// Pomo's own brand palette — the single source of truth for app-level colours
/// that aren't part of the Hudson design system.
///
/// To retint the standard focus template across the whole app, change the one
/// `accent` value below; everything that follows the focus accent updates with it.
enum PomoBrand {
    /// The Pomo accent — matches the website accent (`#eae434`).
    static let accent = Color(hex: 0xEAE434)
}

extension Color {
    /// Build a colour from a `0xRRGGBB` hex literal, e.g. `Color(hex: 0xEAE434)`.
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
