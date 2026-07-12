import SwiftUI

struct TimerView: View {
    @EnvironmentObject private var timerManager: TimerManager
    @EnvironmentObject private var statsManager: StatsManager
    @AppStorage("dailyGoal") private var dailyGoal = 8
    @AppStorage("focusFace") private var faceRaw = FocusFace.chronograph.rawValue
    @State private var showingFacePicker = false
    @State private var showingFocusMode = false

    private var face: FocusFace {
        get { FocusFace(storedValue: faceRaw) }
        nonmutating set { faceRaw = newValue.rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    header
                    modeAndFaceRow
                    intentField
                    faceCard
                    controls
                    cadence
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .pomoScreen()
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                // Normalize the original display-name values to the shared
                // macOS identities without changing what existing users see.
                if faceRaw != face.rawValue {
                    faceRaw = face.rawValue
                }
            }
            .sheet(isPresented: $showingFacePicker) {
                FocusFacePickerSheet(selection: Binding(get: { face }, set: { face = $0 }))
            }
            .fullScreenCover(isPresented: $showingFocusMode) {
                ZStack {
                    PomoPalette.background.ignoresSafeArea()
                    selectedFace
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showingFocusMode = false
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(timerManager.currentMode.rawValue), \(timerManager.formattedTime) remaining")
                .accessibilityHint("Tap to return to Pomo")
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
                .preferredColorScheme(.dark)
            }
            .alert("Session complete", isPresented: $timerManager.showingCompletion) {
                Button("Continue", role: .cancel) {}
            } message: {
                Text(timerManager.completionMessage)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            PomoWordmark()
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("TODAY")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(PomoPalette.dim)
                Text("\(statsManager.todaySessions) / \(dailyGoal)")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(statsManager.todaySessions >= dailyGoal ? PomoPalette.green : PomoPalette.ink)
            }
        }
    }

    private var modeAndFaceRow: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(FocusMode.allCases) { mode in
                    Button {
                        timerManager.switchToMode(mode)
                    } label: {
                        Label("\(mode.rawValue) · \(Int(timerManager.duration(for: mode) / 60)) min", systemImage: mode.icon)
                    }
                }
            } label: {
                HStack(spacing: 9) {
                    Circle()
                        .fill(timerManager.currentMode.color)
                        .frame(width: 7, height: 7)
                    Text(timerManager.currentMode.rawValue)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(PomoPalette.ink)
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(Capsule().fill(PomoPalette.surface))
                .overlay(Capsule().stroke(PomoPalette.border, lineWidth: 1))
            }

            Spacer()
            Text("\(Int(timerManager.duration(for: timerManager.currentMode) / 60)) MIN")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(PomoPalette.dim)
        }
    }

    private var intentField: some View {
        VStack(alignment: .leading, spacing: 9) {
            PomoSectionLabel(title: "Intent", trailing: timerManager.isActive ? "locked in" : nil)
            HStack(spacing: 10) {
                Image(systemName: "scope")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PomoPalette.accent)
                TextField("What are you focusing on?", text: $timerManager.intent)
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundStyle(PomoPalette.ink)
                    .submitLabel(.done)
                    .disabled(timerManager.isActive)
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(PomoPalette.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(timerManager.isActive ? PomoPalette.accent.opacity(0.25) : PomoPalette.border, lineWidth: 1)
                    }
            )
        }
    }

    private var faceCard: some View {
        selectedFace
        .environmentObject(timerManager)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(PomoPalette.elevated)
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(PomoPalette.border, lineWidth: 1)
        }
        .shadow(color: timerManager.currentMode.color.opacity(timerManager.isActive ? 0.14 : 0.05), radius: 30, y: 16)
        .onLongPressGesture {
            showingFacePicker = true
        }
        .onTapGesture {
            showingFocusMode = true
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(timerManager.currentMode.rawValue), \(timerManager.formattedTime) remaining")
        .accessibilityHint("Tap for focus mode. Long press to choose a timer face")
        .accessibilityAction(named: "Open focus mode") {
            showingFocusMode = true
        }
        .accessibilityAction(named: "Choose timer face") {
            showingFacePicker = true
        }
    }

    @ViewBuilder
    private var selectedFace: some View {
        switch face {
        case .minimal:
            MinimalTimerFace()
        case .terminal:
            TerminalTimerFace()
        case .neon:
            NeonTimerFace()
        case .retroDigital:
            RetroDigitalTimerFace()
        case .rolodex:
            RolodexTimerFace()
        case .chronograph:
            DialFace()
        case .blueprint:
            BlueprintTimerFace()
        }
    }

    private var controls: some View {
        HStack(spacing: 22) {
            PomoIconButton(systemName: "arrow.counterclockwise", label: "Reset timer") {
                timerManager.resetTimer()
            }

            PomoIconButton(
                systemName: timerManager.isActive ? "pause.fill" : "play.fill",
                label: timerManager.isActive ? "Pause timer" : "Start timer",
                primary: true
            ) {
                if timerManager.isActive {
                    timerManager.pauseTimer()
                } else {
                    timerManager.startTimer()
                }
            }

            PomoIconButton(systemName: "forward.end.fill", label: "Skip session") {
                timerManager.skipToNext()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }

    private var cadence: some View {
        VStack(spacing: 12) {
            PomoSectionLabel(title: "Cadence", trailing: "long break after four")
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index < timerManager.completedPomodoros % 4 ? PomoPalette.accent : PomoPalette.surfaceStrong)
                        .frame(maxWidth: .infinity)
                        .frame(height: 5)
                }
            }
        }
    }
}

private struct DialFace: View {
    @EnvironmentObject private var timer: TimerManager

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = size * 0.39

            ZStack {
                Canvas { context, _ in
                    for index in 0..<60 {
                        let angle = Double(index) / 60 * .pi * 2 - .pi / 2
                        let major = index % 5 == 0
                        let outer = CGPoint(
                            x: center.x + cos(angle) * radius,
                            y: center.y + sin(angle) * radius
                        )
                        let innerRadius = radius - (major ? 14 : 7)
                        let inner = CGPoint(
                            x: center.x + cos(angle) * innerRadius,
                            y: center.y + sin(angle) * innerRadius
                        )
                        var path = Path()
                        path.move(to: inner)
                        path.addLine(to: outer)
                        context.stroke(
                            path,
                            with: .color(index == 0 ? timer.currentMode.color : PomoPalette.ink.opacity(major ? 0.38 : 0.12)),
                            lineWidth: index == 0 ? 2.5 : (major ? 1.8 : 1)
                        )
                    }
                }

                Circle()
                    .trim(from: 0, to: max(timer.progress, 0.008))
                    .stroke(
                        timer.currentMode.color,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: size * 0.67, height: size * 0.67)
                    .shadow(color: timer.currentMode.color.opacity(0.16), radius: 6)
                    .animation(.linear(duration: 0.2), value: timer.progress)

                Circle()
                    .fill(PomoPalette.elevated)
                    .frame(width: size * 0.47, height: size * 0.47)

                VStack(spacing: 14) {
                    Text(timer.currentMode.label)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(PomoPalette.dim)
                    Text(timer.formattedTime)
                        .font(.system(size: size * 0.145, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(PomoPalette.ink)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(timer.isActive ? PomoPalette.green : PomoPalette.dim)
                            .frame(width: 6, height: 6)
                        Text(timer.isActive ? "IN SESSION" : "READY")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(PomoPalette.muted)
                    }
                }
            }
        }
        .padding(14)
    }
}

private struct TerminalFace: View {
    @EnvironmentObject private var timer: TimerManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("POMO / SESSION")
                Spacer()
                Text(timer.isActive ? "RUNNING" : "IDLE")
                    .foregroundStyle(timer.isActive ? PomoPalette.green : PomoPalette.dim)
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(1.1)
            .foregroundStyle(PomoPalette.dim)

            Spacer()

            Text("> \(timer.currentMode.label.lowercased().replacingOccurrences(of: " ", with: "_"))")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(timer.currentMode.color)

            Text(timer.formattedTime)
                .font(.system(size: 58, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(PomoPalette.ink)
                .minimumScaleFactor(0.7)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(PomoPalette.surfaceStrong)
                    Capsule()
                        .fill(timer.currentMode.color)
                        .frame(width: max(proxy.size.width * timer.progress, 4))
                }
            }
            .frame(height: 4)
            .padding(.top, 10)

            Spacer()

            Text(timer.intent.isEmpty ? "awaiting intent_" : timer.intent + (timer.isActive ? "" : "_"))
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(PomoPalette.muted)
                .lineLimit(1)
        }
        .padding(26)
    }
}

private struct BlueprintFace: View {
    @EnvironmentObject private var timer: TimerManager

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Canvas { context, size in
                    let step: CGFloat = 22
                    var grid = Path()
                    stride(from: CGFloat.zero, through: size.width, by: step).forEach { x in
                        grid.move(to: CGPoint(x: x, y: 0))
                        grid.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    stride(from: CGFloat.zero, through: size.height, by: step).forEach { y in
                        grid.move(to: CGPoint(x: 0, y: y))
                        grid.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(grid, with: .color(PomoPalette.blue.opacity(0.09)), lineWidth: 0.7)

                    var crosshair = Path()
                    crosshair.move(to: CGPoint(x: size.width / 2, y: 18))
                    crosshair.addLine(to: CGPoint(x: size.width / 2, y: size.height - 18))
                    crosshair.move(to: CGPoint(x: 18, y: size.height / 2))
                    crosshair.addLine(to: CGPoint(x: size.width - 18, y: size.height / 2))
                    context.stroke(crosshair, with: .color(PomoPalette.blue.opacity(0.22)), lineWidth: 1)
                }

                Circle()
                    .stroke(PomoPalette.blue.opacity(0.30), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .padding(42)

                Circle()
                    .trim(from: 0, to: max(timer.progress, 0.01))
                    .stroke(timer.currentMode.color, style: StrokeStyle(lineWidth: 3, lineCap: .square))
                    .rotationEffect(.degrees(-90))
                    .padding(42)

                VStack(spacing: 10) {
                    Text("DWG · 25.001")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(PomoPalette.blue.opacity(0.75))
                    Text(timer.formattedTime)
                        .font(.system(size: min(proxy.size.width * 0.16, 58), weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(PomoPalette.ink)
                    Text(timer.currentMode.label + " / 1:1")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(timer.currentMode.color)
                }

                VStack {
                    HStack {
                        Text("POMO FOCUS INSTRUMENT")
                        Spacer()
                        Text("REV A")
                    }
                    Spacer()
                    HStack {
                        Text("ELAPSED \(Int(timer.progress * 100))%")
                        Spacer()
                        Text(timer.isActive ? "ACTIVE" : "STANDBY")
                    }
                }
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(PomoPalette.blue.opacity(0.62))
                .padding(20)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

#Preview {
    TimerView()
        .environmentObject(TimerManager())
        .environmentObject(StatsManager())
}
