import SwiftUI

/// Pomo's adaptive surface palette — the colours for app **windows** (Settings,
/// Stats) that sit against the user's desktop and therefore follow the system
/// light/dark appearance.
///
/// Hudson's `HudPalette` / `HudSurface` are deliberately fixed-dark (they dress
/// the always-dark HUD), so we can't lean on them here. Rather than depend on a
/// framework "light" palette of unknown completeness, Pomo owns both ends of the
/// ramp explicitly — the same approach the Lattices app takes with its `Palette`.
/// Dark values mirror the HUD's near-black glass; light values are a clean,
/// System-Settings-flavoured on-light treatment.
struct AppPalette {
    /// Detail / content background.
    let bg: Color
    /// Sidebar background (slightly offset from `bg` for separation).
    let sidebar: Color
    /// Raised card fill.
    let surface: Color
    /// Hover / selected row fill.
    let surfaceHover: Color
    /// Recessed control fill (text fields, icon buttons).
    let inset: Color
    /// Primary text.
    let ink: Color
    /// Secondary text.
    let muted: Color
    /// Tertiary text / disabled.
    let dim: Color
    /// Card / control borders.
    let border: Color
    /// Hairline dividers (lighter than `border`).
    let hairline: Color
    /// Brand accent (Pomo yellow) — used sparingly, e.g. the hourglass.
    let accent: Color
    /// Functional action accent (green) — primary buttons, toggles, sliders.
    let action: Color

    static let dark = AppPalette(
        bg:           Color(hex: 0x161618),
        sidebar:      Color(hex: 0x111113),
        surface:      Color(hex: 0x202023),
        surfaceHover: Color(hex: 0x2A2A2E),
        inset:        Color(hex: 0x0D0D0F),
        ink:          Color.white.opacity(0.92),
        muted:        Color.white.opacity(0.60),
        dim:          Color.white.opacity(0.40),
        border:       Color.white.opacity(0.08),
        hairline:     Color.white.opacity(0.06),
        accent:       PomoBrand.accent,
        action:       Color(hex: 0x3DD66B)
    )

    static let light = AppPalette(
        bg:           Color(hex: 0xF5F5F7),
        sidebar:      Color(hex: 0xECECEE),
        surface:      Color(hex: 0xFFFFFF),
        surfaceHover: Color.black.opacity(0.045),
        inset:        Color.black.opacity(0.05),
        ink:          Color(hex: 0x1B1B20),
        muted:        Color.black.opacity(0.56),
        dim:          Color.black.opacity(0.40),
        border:       Color.black.opacity(0.10),
        hairline:     Color.black.opacity(0.07),
        accent:       PomoBrand.accent,
        action:       Color(hex: 0x27B257)
    )

    static func resolve(_ scheme: ColorScheme) -> AppPalette {
        scheme == .light ? .light : .dark
    }
}
