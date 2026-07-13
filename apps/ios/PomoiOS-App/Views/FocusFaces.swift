import SwiftUI
import UIKit

enum FocusFace: String, CaseIterable, Identifiable {
    case minimal
    case terminal
    case neon
    case retroDigital
    case rolodex
    case chronograph
    case blueprint
    case photo

    var id: String { rawValue }

    init(storedValue: String) {
        // The original iOS values used display names. Preserve all three so
        // existing installs keep their chosen face as the collection expands.
        switch storedValue {
        case "Dial": self = .chronograph
        case "Terminal": self = .terminal
        case "Blueprint": self = .blueprint
        default: self = FocusFace(rawValue: storedValue) ?? .chronograph
        }
    }

    var displayName: String {
        switch self {
        case .minimal: "Minimal"
        case .terminal: "Terminal"
        case .neon: "Neon"
        case .retroDigital: "Retro Digital"
        case .rolodex: "Rolodex"
        case .chronograph: "Chronograph"
        case .blueprint: "Blueprint"
        case .photo: "Photo"
        }
    }

    var accent: Color {
        switch self {
        case .minimal, .chronograph: PomoPalette.accent
        case .terminal: Color(red: 0.35, green: 1, blue: 0.55)
        case .neon: Color(red: 0.25, green: 0.95, blue: 1)
        case .retroDigital: Color(red: 1, green: 0.78, blue: 0.18)
        case .rolodex: Color.white.opacity(0.86)
        case .blueprint: PomoPalette.blue
        case .photo: Color.white
        }
    }
}

struct FocusFacePicker: View {
    @EnvironmentObject private var photoFaceStore: PhotoFaceStore
    @Binding var selection: FocusFace
    @State private var centeredFace: FocusFace?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PomoSectionLabel(title: "Face", trailing: selection.displayName)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(FocusFace.allCases) { face in
                        Button {
                            withAnimation(.snappy(duration: 0.22, extraBounce: 0)) {
                                selection = face
                            }
                        } label: {
                            VStack(spacing: 7) {
                                FaceThumbnail(face: face, selected: face == selection, photo: photoFaceStore.image)
                                    .frame(width: 66, height: 50)

                                Text(face.displayName)
                                    .font(.system(size: 9, weight: face == selection ? .bold : .medium, design: .monospaced))
                                    .foregroundStyle(face == selection ? PomoPalette.ink : PomoPalette.muted)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                    .frame(width: 72)
                            }
                            .padding(.top, 6)
                            .padding(.bottom, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Use \(face.displayName) face")
                        .accessibilityAddTraits(face == selection ? .isSelected : [])
                        .id(face)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $centeredFace, anchor: .center)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .onAppear {
                centeredFace = selection
            }
            .onChange(of: selection) { _, face in
                withAnimation(.snappy(duration: 0.22, extraBounce: 0)) {
                    centeredFace = face
                }
            }
        }
    }
}

struct FocusFacePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: FocusFace

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Timer face")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(PomoPalette.ink)
                    Text("Choose a look for the timer.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(PomoPalette.muted)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PomoPalette.muted)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(PomoPalette.surfaceStrong))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }

            FocusFacePicker(selection: $selection)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 12)
        .background(PomoPalette.background.ignoresSafeArea())
        .presentationDetents([.height(235)])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
}

private struct FaceThumbnail: View {
    let face: FocusFace
    let selected: Bool
    let photo: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(background)

            if face == .photo {
                photoMotif
            } else {
                motif
                    .foregroundStyle(face.accent)
                    .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(selected ? face.accent : PomoPalette.border, lineWidth: selected ? 1.5 : 1)
        }
        .shadow(color: selected ? face.accent.opacity(0.16) : .clear, radius: 9)
        .scaleEffect(selected ? 1 : 0.96)
    }

    @ViewBuilder
    private var motif: some View {
        switch face {
        case .minimal:
            VStack(spacing: 5) {
                Text("25:00").font(.system(size: 10, weight: .semibold, design: .monospaced))
                Capsule().frame(height: 2)
            }
        case .terminal:
            HStack(spacing: 2) {
                Text(">").opacity(0.55)
                Text("25:00_")
            }
            .font(.system(size: 9, weight: .bold, design: .monospaced))
        case .neon:
            Circle()
                .trim(from: 0, to: 0.74)
                .stroke(
                    AngularGradient(colors: [.pink, face.accent, .pink], center: .center),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(3)
                .shadow(color: face.accent, radius: 4)
        case .retroDigital:
            Text("25:00")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .shadow(color: face.accent.opacity(0.65), radius: 3)
        case .rolodex:
            HStack(spacing: 2) {
                ForEach(Array([2, 5, 0, 0].enumerated()), id: \.offset) { _, digit in
                    Text("\(digit)")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 10, height: 18)
                        .background(RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.12)))
                }
            }
        case .chronograph:
            ZStack {
                Circle().stroke(PomoPalette.ink.opacity(0.3), lineWidth: 1)
                Circle().trim(from: 0, to: 0.7).stroke(face.accent, lineWidth: 2).rotationEffect(.degrees(-90))
                Capsule().frame(width: 1.5, height: 13).offset(y: -6).rotationEffect(.degrees(210))
                Circle().frame(width: 4, height: 4)
            }
            .padding(1)
        case .blueprint:
            ZStack {
                BlueprintMiniGrid().opacity(0.35)
                Circle().stroke(style: StrokeStyle(lineWidth: 1, dash: [2, 2])).padding(2)
                Text("25:00").font(.system(size: 8, weight: .bold, design: .monospaced))
            }
        case .photo:
            EmptyView()
        }
    }

    @ViewBuilder
    private var photoMotif: some View {
        if let photo {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .overlay {
                    LinearGradient(colors: [.clear, .black.opacity(0.52)], startPoint: .top, endPoint: .bottom)
                }
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(7)
                }
        } else {
            VStack(spacing: 4) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 15, weight: .medium))
                Text("ADD")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .tracking(1)
            }
            .foregroundStyle(PomoPalette.muted)
        }
    }

    private var background: some ShapeStyle {
        switch face {
        case .terminal: Color.black.opacity(0.82)
        case .neon: Color(red: 0.04, green: 0.02, blue: 0.08)
        case .retroDigital: Color(red: 0.08, green: 0.06, blue: 0.03)
        case .rolodex: Color(red: 0.08, green: 0.08, blue: 0.10)
        case .blueprint: Color(red: 0.063, green: 0.078, blue: 0.098)
        case .photo: Color.black.opacity(0.82)
        case .minimal, .chronograph: PomoPalette.surface
        }
    }
}

private struct BlueprintMiniGrid: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            for x in stride(from: 0.0, through: size.width, by: 7) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 0.0, through: size.height, by: 7) {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(PomoPalette.blue), lineWidth: 0.5)
        }
    }
}

// MARK: - macOS face identities, adapted to the iPhone canvas

struct PhotoTimerFace: View {
    @EnvironmentObject private var timer: TimerManager
    @EnvironmentObject private var photoFaceStore: PhotoFaceStore

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                background(size: proxy.size)

                Color.black.opacity(photoFaceStore.image == nil ? 0.16 : 0.20)

                LinearGradient(
                    colors: [.black.opacity(0.54), .clear, .black.opacity(0.62)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Circle()
                    .stroke(Color.white.opacity(0.24), lineWidth: 7)
                    .padding(42)

                Circle()
                    .trim(from: 0, to: max(timer.progress, 0.008))
                    .stroke(timer.currentMode.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(42)
                    .shadow(color: timer.currentMode.color.opacity(0.34), radius: 10)

                VStack(spacing: 12) {
                    Text(timer.currentMode.label)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(3)

                    Text(timer.formattedTime)
                        .font(.system(size: min(proxy.size.width * 0.15, 58), weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    Text(timer.intent.isEmpty ? (timer.isActive ? "IN SESSION" : "READY") : timer.intent)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(timer.intent.isEmpty ? 1.6 : 0.4)
                        .lineLimit(1)
                        .padding(.horizontal, 34)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.86), radius: 8, y: 2)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }

    @ViewBuilder
    private func background(size: CGSize) -> some View {
        if let image = photoFaceStore.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
        } else {
            ZStack {
                LinearGradient(
                    colors: [PomoPalette.surfaceStrong, PomoPalette.background],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: 10) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 32, weight: .light))
                    Text("Choose a photo in Settings")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                }
                .foregroundStyle(PomoPalette.muted)
                .offset(y: size.height * 0.26)
            }
        }
    }
}

struct MinimalTimerFace: View {
    @EnvironmentObject private var timer: TimerManager

    var body: some View {
        VStack(spacing: 22) {
            Text(timer.intent.isEmpty ? timer.currentMode.label : timer.intent)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(timer.intent.isEmpty ? 2 : 0.5)
                .foregroundStyle(PomoPalette.muted)
                .lineLimit(1)

            Text(timer.formattedTime)
                .font(.system(size: 56, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(PomoPalette.ink)
                .contentTransition(.numericText())

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(timer.currentMode.color)
                        .frame(width: max(3, proxy.size.width * timer.progress))
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 28)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [Color(white: 0.12), Color(white: 0.05)], startPoint: .top, endPoint: .bottom)
        )
    }
}

struct TerminalTimerFace: View {
    @EnvironmentObject private var timer: TimerManager
    private let green = Color(red: 0.35, green: 1, blue: 0.55)

    private var cells: Int { 18 }
    private var asciiBar: String {
        let filled = Int((Double(cells) * timer.progress).rounded(.down))
        return String(repeating: "█", count: filled) + String(repeating: "░", count: cells - filled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("pomo")
                Text("~/\(timer.currentMode.rawValue.lowercased().replacingOccurrences(of: " ", with: "-"))")
                    .opacity(0.5)
                Spacer()
                Text(timer.isActive ? "RUN" : "IDLE").opacity(timer.isActive ? 1 : 0.5)
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))

            Rectangle().fill(green.opacity(0.18)).frame(height: 1)
            Spacer()

            HStack(spacing: 7) {
                Text(">").opacity(0.5)
                Text(timer.formattedTime)
                    .font(.system(size: 42, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                Rectangle().frame(width: 9, height: 28)
            }

            HStack(spacing: 7) {
                Text("[\(asciiBar)]")
                Text("\(Int((timer.progress * 100).rounded()))%").opacity(0.5)
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))

            Spacer()
            Text(timer.intent.isEmpty ? "awaiting intent_" : timer.intent + "_")
                .font(.system(size: 11, design: .monospaced))
                .opacity(0.6)
                .lineLimit(1)
        }
        .foregroundStyle(green)
        .padding(25)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ZStack { Color.black.opacity(0.72); ScanlineOverlay().opacity(0.22) })
    }
}

private struct ScanlineOverlay: View {
    var body: some View {
        Canvas { context, size in
            for y in stride(from: 0.0, through: size.height, by: 4) {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.black))
            }
        }
        .allowsHitTesting(false)
    }
}

struct NeonTimerFace: View {
    @EnvironmentObject private var timer: TimerManager
    private let magenta = Color(red: 1, green: 0.18, blue: 0.85)
    private let cyan = Color(red: 0.25, green: 0.95, blue: 1)

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.07), lineWidth: 10).padding(38)
            Circle()
                .trim(from: 0, to: max(0.001, timer.progress))
                .stroke(gradient, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .blur(radius: 11)
                .opacity(0.9)
                .padding(38)
            Circle()
                .trim(from: 0, to: max(0.001, timer.progress))
                .stroke(gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(38)

            VStack(spacing: 10) {
                Text(timer.currentMode.label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(cyan)
                    .shadow(color: cyan, radius: 6)
                Text(timer.formattedTime)
                    .font(.system(size: 40, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .shadow(color: magenta, radius: 10)
                Text(timer.isActive ? "● LIVE" : "○ READY")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(timer.isActive ? magenta : Color.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.04, green: 0.02, blue: 0.08))
    }

    private var gradient: AngularGradient {
        AngularGradient(colors: [magenta, cyan, magenta], center: .center, startAngle: .degrees(-90), endAngle: .degrees(270))
    }
}

struct RetroDigitalTimerFace: View {
    @EnvironmentObject private var timer: TimerManager
    private let amber = Color(red: 1, green: 0.78, blue: 0.18)

    private var digits: [Int] {
        let seconds = max(0, Int(timer.timeRemaining.rounded(.up)))
        let minutes = min(99, seconds / 60)
        return [minutes / 10, minutes % 10, (seconds % 60) / 10, seconds % 10]
    }

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                Text(timer.currentMode.label)
                Spacer()
                Text(timer.isActive ? "RUN" : "SET").opacity(0.65)
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(2)

            HStack(spacing: 7) {
                SegmentDigit(value: digits[0], color: amber)
                SegmentDigit(value: digits[1], color: amber)
                VStack(spacing: 14) {
                    Circle().frame(width: 7, height: 7)
                    Circle().frame(width: 7, height: 7)
                }
                .frame(width: 9)
                SegmentDigit(value: digits[2], color: amber)
                SegmentDigit(value: digits[3], color: amber)
            }
            .frame(height: 82)
            .shadow(color: amber.opacity(0.55), radius: 8)
        }
        .foregroundStyle(amber)
        .padding(26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [Color(red: 0.08, green: 0.06, blue: 0.03), .black], startPoint: .top, endPoint: .bottom))
    }
}

private struct SegmentDigit: View {
    let value: Int
    let color: Color

    private static let map: [Int: Set<Character>] = [
        0: ["a", "b", "c", "d", "e", "f"], 1: ["b", "c"], 2: ["a", "b", "g", "e", "d"],
        3: ["a", "b", "g", "c", "d"], 4: ["f", "g", "b", "c"], 5: ["a", "f", "g", "c", "d"],
        6: ["a", "f", "g", "e", "c", "d"], 7: ["a", "b", "c"],
        8: ["a", "b", "c", "d", "e", "f", "g"], 9: ["a", "b", "c", "d", "f", "g"]
    ]

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let thickness = min(width, height) * 0.15
            let lit = Self.map[value] ?? []
            ZStack {
                segment(lit.contains("a"), horizontal: true, length: width - thickness * 1.5, thickness: thickness).position(x: width / 2, y: thickness / 2)
                segment(lit.contains("g"), horizontal: true, length: width - thickness * 1.5, thickness: thickness).position(x: width / 2, y: height / 2)
                segment(lit.contains("d"), horizontal: true, length: width - thickness * 1.5, thickness: thickness).position(x: width / 2, y: height - thickness / 2)
                segment(lit.contains("f"), horizontal: false, length: height / 2 - thickness * 1.3, thickness: thickness).position(x: thickness / 2, y: height * 0.25)
                segment(lit.contains("b"), horizontal: false, length: height / 2 - thickness * 1.3, thickness: thickness).position(x: width - thickness / 2, y: height * 0.25)
                segment(lit.contains("e"), horizontal: false, length: height / 2 - thickness * 1.3, thickness: thickness).position(x: thickness / 2, y: height * 0.75)
                segment(lit.contains("c"), horizontal: false, length: height / 2 - thickness * 1.3, thickness: thickness).position(x: width - thickness / 2, y: height * 0.75)
            }
        }
        .aspectRatio(0.58, contentMode: .fit)
    }

    private func segment(_ on: Bool, horizontal: Bool, length: CGFloat, thickness: CGFloat) -> some View {
        Capsule()
            .fill(color.opacity(on ? 1 : 0.10))
            .frame(width: horizontal ? length : thickness, height: horizontal ? thickness : length)
    }
}

struct RolodexTimerFace: View {
    @EnvironmentObject private var timer: TimerManager

    private var digits: [Int] {
        let seconds = max(0, Int(timer.timeRemaining.rounded(.up)))
        let minutes = min(99, seconds / 60)
        return [minutes / 10, minutes % 10, (seconds % 60) / 10, seconds % 10]
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(timer.intent.isEmpty ? timer.currentMode.label : timer.intent)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(timer.intent.isEmpty ? 2 : 0.5)
                .foregroundStyle(PomoPalette.muted)
                .lineLimit(1)

            HStack(spacing: 5) {
                FlipTimerDigit(value: digits[0])
                FlipTimerDigit(value: digits[1])
                VStack(spacing: 15) {
                    Circle().fill(.white.opacity(0.85)).frame(width: 7, height: 7)
                    Circle().fill(.white.opacity(0.85)).frame(width: 7, height: 7)
                }
                .frame(width: 11)
                FlipTimerDigit(value: digits[2])
                FlipTimerDigit(value: digits[3])
            }
            .frame(height: 78)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [Color(red: 0.10, green: 0.10, blue: 0.12), .black], startPoint: .top, endPoint: .bottom))
    }
}

private struct FlipTimerDigit: View {
    let value: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.22), Color(white: 0.11)], startPoint: .top, endPoint: .bottom))
            Text("\(value)")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .id(value)
                .transition(.push(from: .top).combined(with: .opacity))
            Rectangle().fill(.black.opacity(0.5)).frame(height: 2)
        }
        .frame(maxWidth: 50, maxHeight: 74)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.white.opacity(0.08)))
        .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
        .animation(.snappy(duration: 0.16, extraBounce: 0), value: value)
    }
}

struct BlueprintTimerFace: View {
    @EnvironmentObject private var timer: TimerManager
    private let paper = Color(red: 0.102, green: 0.122, blue: 0.149)
    private let edge = Color(red: 0.035, green: 0.047, blue: 0.063)
    private let ink = Color(red: 0.910, green: 0.922, blue: 0.937)
    private let secondary = Color(red: 0.604, green: 0.639, blue: 0.682)

    var body: some View {
        ZStack {
            RadialGradient(colors: [paper, edge], center: .center, startRadius: 10, endRadius: 240)
            BlueprintGrid().opacity(0.62)

            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("SHEET 01 / 01").foregroundStyle(secondary.opacity(0.7))
                        Text("POMO · TIMER").foregroundStyle(secondary)
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SESSION").foregroundStyle(secondary.opacity(0.7))
                        Text(timer.currentMode.label).foregroundStyle(ink)
                    }
                    .padding(6)
                    .overlay(Rectangle().stroke(secondary.opacity(0.5)))
                }
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .tracking(1.2)

                Spacer()
                Text(timer.formattedTime)
                    .font(.system(size: 50, weight: .medium, design: .monospaced))
                    .tracking(1)
                    .monospacedDigit()
                    .foregroundStyle(ink)

                HStack(spacing: 8) {
                    Rectangle().frame(height: 1)
                    Text("REMAINING")
                    Rectangle().frame(height: 1)
                }
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(secondary)
                .padding(.horizontal, 30)
                .padding(.top, 12)
                Spacer()

                HStack {
                    Circle().fill(timer.isActive ? timer.currentMode.color : secondary).frame(width: 5, height: 5)
                    Text(timer.isActive ? "RUNNING" : "STANDBY")
                    Spacer()
                    Text("Ø \(Int((timer.progress * 100).rounded()))%")
                }
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .tracking(1.3)
                .foregroundStyle(secondary)
                .padding(8)
                .overlay(Rectangle().stroke(secondary.opacity(0.4)))
            }
            .padding(21)
        }
        .overlay(Rectangle().stroke(secondary.opacity(0.45)).padding(9))
    }
}

private struct BlueprintGrid: View {
    var body: some View {
        Canvas { context, size in
            var minor = Path()
            var major = Path()
            for (index, x) in stride(from: 0.0, through: size.width, by: 12).enumerated() {
                var path = index % 6 == 0 ? major : minor
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                if index % 6 == 0 { major = path } else { minor = path }
            }
            for (index, y) in stride(from: 0.0, through: size.height, by: 12).enumerated() {
                var path = index % 6 == 0 ? major : minor
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                if index % 6 == 0 { major = path } else { minor = path }
            }
            context.stroke(minor, with: .color(Color(red: 0.165, green: 0.192, blue: 0.227)), lineWidth: 0.7)
            context.stroke(major, with: .color(Color(red: 0.227, green: 0.259, blue: 0.302)), lineWidth: 1)
        }
    }
}
