import SwiftUI

enum PomoPalette {
    static let background = Color(hex: 0x17120F)
    static let elevated = Color(hex: 0x201913)
    static let surface = Color(hex: 0x251D17)
    static let surfaceStrong = Color(hex: 0x30261E)
    static let border = Color.white.opacity(0.09)
    static let ink = Color(hex: 0xF4EEE6)
    static let muted = Color(hex: 0xBCAE9E)
    static let dim = Color(hex: 0x7D7165)
    static let accent = Color(hex: 0xEAE434)
    static let green = Color(hex: 0x5ED69A)
    static let blue = Color(hex: 0x70B7FF)
    static let orange = Color(hex: 0xF2A65A)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: opacity
        )
    }
}

struct PomoPanel: ViewModifier {
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(PomoPalette.elevated)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(PomoPalette.border, lineWidth: 1)
                    }
            )
    }
}

extension View {
    func pomoPanel(padding: CGFloat = 18) -> some View {
        modifier(PomoPanel(padding: padding))
    }

    func pomoScreen() -> some View {
        background(PomoPalette.background.ignoresSafeArea())
            .preferredColorScheme(.dark)
    }
}

struct PomoSectionLabel: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(PomoPalette.dim)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(PomoPalette.muted)
            }
        }
    }
}

struct PomoWordmark: View {
    var body: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 2)
                .fill(PomoPalette.accent)
                .frame(width: 18, height: 3)
            Text("POMO")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(3)
                .foregroundStyle(PomoPalette.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pomo")
    }
}

struct PomoIconButton: View {
    let systemName: String
    let label: String
    var primary = false
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: primary ? 23 : 17, weight: .semibold))
                .foregroundStyle(primary ? PomoPalette.background : (disabled ? PomoPalette.dim : PomoPalette.ink))
                .frame(width: primary ? 72 : 54, height: primary ? 72 : 54)
                .background(
                    Circle()
                        .fill(primary ? PomoPalette.accent : PomoPalette.surface)
                        .overlay {
                            if !primary {
                                Circle().stroke(PomoPalette.border, lineWidth: 1)
                            }
                        }
                )
                .shadow(color: primary ? PomoPalette.accent.opacity(0.22) : .clear, radius: 16, y: 7)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(label)
    }
}

struct PomoToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 14) {
                configuration.label
                Spacer()
                Capsule()
                    .fill(configuration.isOn ? PomoPalette.accent : PomoPalette.surfaceStrong)
                    .frame(width: 48, height: 28)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(configuration.isOn ? PomoPalette.background : PomoPalette.muted)
                            .frame(width: 22, height: 22)
                            .padding(3)
                    }
            }
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: configuration.isOn)
    }
}
