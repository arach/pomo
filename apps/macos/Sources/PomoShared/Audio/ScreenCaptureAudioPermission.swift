import AppKit
import Combine
import CoreServices
import CoreGraphics
import Foundation
import SwiftUI

enum ScreenCaptureAudioPermission {
    static let neededMessage = "audio scope needs macOS screen/system audio permission"
    static let requirementLabel = "Screen & System Audio Recording"
    static let tccService = "AudioCapture"
    static let legacyTCCService = "ScreenCapture"
    private static let successfulAccessUntilKey = "pomo.visualizerAudio.successfulAccessUntil"
    private static let successfulAccessTTL: TimeInterval = 60 * 60

    struct PermissionTarget: Equatable {
        let appURL: URL
        let bundleIdentifier: String
        let displayName: String
        let isAppBundle: Bool

        var path: String { appURL.path }
    }

    static var permissionTarget: PermissionTarget {
        let appURL = appBundleURL(for: Bundle.main.bundleURL)
        let bundle = Bundle(url: appURL) ?? Bundle.main
        let bundleIdentifier = bundle.bundleIdentifier
            ?? Bundle.main.bundleIdentifier
            ?? ""
        let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? appURL.deletingPathExtension().lastPathComponent
        return PermissionTarget(
            appURL: appURL,
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            isAppBundle: appBundleExists(at: appURL)
        )
    }

    static var systemReportsAccess: Bool {
        CGPreflightScreenCaptureAccess()
    }

    static var hasAccess: Bool {
        systemReportsAccess || hasRecentSuccessfulAccess
    }

    private static var hasRecentSuccessfulAccess: Bool {
        UserDefaults.standard.double(forKey: successfulAccessUntilKey) > Date().timeIntervalSince1970
    }

    static func recordSuccessfulAccess(ttl: TimeInterval = successfulAccessTTL) {
        UserDefaults.standard.set(Date().addingTimeInterval(ttl).timeIntervalSince1970, forKey: successfulAccessUntilKey)
    }

    static func clearCachedAccess() {
        UserDefaults.standard.removeObject(forKey: successfulAccessUntilKey)
    }

    static func isPermissionError(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("permission")
            || lowercased.contains("not authorized")
            || lowercased.contains("not authorised")
            || lowercased.contains("not permitted")
            || lowercased.contains("not allowed")
            || lowercased.contains("denied")
            || lowercased.contains("declined")
            || lowercased.contains("tcc")
    }

    @MainActor
    static func showAssistant(startRequest: Bool = false) {
        registerPermissionTarget(reason: "show assistant")
        ScreenCaptureAudioPermissionWindowController.shared.show(startRequest: startRequest)
    }

    static func openSettings() {
        registerPermissionTarget(reason: "open settings")
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    @discardableResult
    static func registerPermissionTarget(reason: String) -> Bool {
        let target = permissionTarget
        guard target.isAppBundle else {
            print("[pomo-permissions] permission target is not an app bundle: \(target.path)")
            return false
        }

        let status = LSRegisterURL(target.appURL as CFURL, true)
        if status == noErr {
            print("[pomo-permissions] registered \(target.bundleIdentifier) at \(target.path) (\(reason))")
            return true
        }

        print("[pomo-permissions] LSRegisterURL failed status=\(status) path=\(target.path)")
        return false
    }

    private static func appBundleURL(for url: URL) -> URL {
        var candidate = url.standardizedFileURL
        if appBundleExists(at: candidate) {
            return candidate
        }

        while candidate.path != "/" {
            if candidate.pathExtension == "app", appBundleExists(at: candidate) {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }

        return url.standardizedFileURL
    }

    private static func appBundleExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.appendingPathComponent("Contents/Info.plist").path)
    }
}

@MainActor
final class ScreenCaptureAudioPermissionChecker: ObservableObject {
    static let shared = ScreenCaptureAudioPermissionChecker()

    @Published private(set) var screenAudio = ScreenCaptureAudioPermission.hasAccess
    @Published private(set) var refreshInFlight = false
    @Published private(set) var lastCheckedAt: Date?
    @Published private(set) var lastMessage: String?

    private var pollTimer: Timer?
    private var burstRefreshTask: Task<Void, Never>?
    private var hasLoggedIdentity = false

    var granted: Bool {
        screenAudio || ScreenCaptureAudioPermission.hasAccess
    }

    func noteSuccessfulAccess(reason: String) {
        ScreenCaptureAudioPermission.recordSuccessfulAccess()
        screenAudio = true
        refreshInFlight = false
        lastCheckedAt = Date()
        lastMessage = "\(ScreenCaptureAudioPermission.requirementLabel) is enabled."
        print("[pomo-permissions] successful visualizer audio capture access (\(reason))")
        stopPolling()
    }

    func check(pollIfMissing: Bool = false) {
        lastCheckedAt = Date()

        let preflight = CGPreflightScreenCaptureAccess()
        let next = ScreenCaptureAudioPermission.hasAccess
        if next != screenAudio {
            lastMessage = next
                ? "\(ScreenCaptureAudioPermission.requirementLabel) is enabled."
                : "macOS still reports \(ScreenCaptureAudioPermission.requirementLabel) is off."
        }
        screenAudio = next

        if !hasLoggedIdentity {
            hasLoggedIdentity = true
            let target = ScreenCaptureAudioPermission.permissionTarget
            let bundleId = Bundle.main.bundleIdentifier ?? "<no bundle id>"
            let execPath = Bundle.main.executablePath ?? ProcessInfo.processInfo.arguments.first ?? "<unknown>"
            let pid = ProcessInfo.processInfo.processIdentifier
            print("[pomo-permissions] bundleId=\(bundleId) pid=\(pid)")
            print("[pomo-permissions] exec=\(execPath)")
            print("[pomo-permissions] permissionTarget bundleId=\(target.bundleIdentifier) path=\(target.path)")
            print("[pomo-permissions] CGPreflightScreenCaptureAccess() -> \(preflight)")
        }

        if screenAudio {
            stopPolling()
        } else if pollIfMissing {
            startPolling()
        }
    }

    func requestScreenAudio() {
        ScreenCaptureAudioPermission.registerPermissionTarget(reason: "request permission")
        check()
        guard !screenAudio else { return }

        refreshInFlight = true
        let target = ScreenCaptureAudioPermission.permissionTarget
        lastMessage = "Opening Settings for \(target.displayName)..."
        NSApp.activate(ignoringOtherApps: true)

        finishRequestAfterPermissionRequest()
    }

    func openSettings() {
        ScreenCaptureAudioPermission.openSettings()
        passiveRecheck(reason: "open settings")
    }

    func passiveRecheck(reason: String) {
        print("[pomo-permissions] passive recheck requested (\(reason))")
        check()
    }

    func recheckNow(reason: String = "manual") {
        print("[pomo-permissions] recheck requested (\(reason))")
        burstRefreshTask?.cancel()
        refreshInFlight = true
        check(pollIfMissing: true)
        schedulePermissionRefresh()
    }

    func resetSavedApproval() {
        let target = ScreenCaptureAudioPermission.permissionTarget
        ScreenCaptureAudioPermission.registerPermissionTarget(reason: "reset saved approval")
        let bundleId = target.bundleIdentifier
        guard !bundleId.isEmpty else { return }
        refreshInFlight = true
        screenAudio = false
        lastMessage = "Clearing saved macOS permission row..."

        DispatchQueue.global(qos: .userInitiated).async {
            let result = Self.runTccutilReset(service: ScreenCaptureAudioPermission.tccService, bundleId: bundleId)
            let legacyResult = Self.runTccutilReset(service: ScreenCaptureAudioPermission.legacyTCCService, bundleId: bundleId)
            DispatchQueue.main.async {
                if result.status == 0 {
                    print("[pomo-permissions] tccutil reset \(ScreenCaptureAudioPermission.tccService) \(bundleId)")
                    if legacyResult.status == 0 {
                        print("[pomo-permissions] tccutil reset \(ScreenCaptureAudioPermission.legacyTCCService) \(bundleId)")
                    }
                    self.lastMessage = "Cleared saved row. Add \(target.displayName) again."
                } else {
                    let detail = result.output.isEmpty ? "exit \(result.status)" : result.output
                    print("[pomo-permissions] tccutil reset \(ScreenCaptureAudioPermission.tccService) failed: \(detail)")
                    self.lastMessage = "Could not clear the saved row: \(detail)"
                }
                self.openSettings()
                self.schedulePermissionRefresh()
            }
        }
    }

    func quitAndRelaunch() {
        let appURL = ScreenCaptureAudioPermission.permissionTarget.appURL
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = [
            "-c",
            "/bin/sleep 1; /usr/bin/open -n \"\(appURL.path)\""
        ]
        try? task.run()
        NSApp.terminate(nil)
    }

    func schedulePermissionRefresh() {
        burstRefreshTask?.cancel()
        refreshInFlight = true
        burstRefreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.refreshInFlight = false }

            let delays: [UInt64] = [
                250_000_000,
                750_000_000,
                1_500_000_000,
                3_000_000_000,
                6_000_000_000,
                10_000_000_000
            ]

            for delay in delays {
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled else { return }
                self.check(pollIfMissing: true)
            }
        }
    }

    private func finishRequestAfterPermissionRequest() {
        screenAudio = ScreenCaptureAudioPermission.hasAccess
        refreshInFlight = false

        if screenAudio {
            lastMessage = "\(ScreenCaptureAudioPermission.requirementLabel) is enabled."
            stopPolling()
        } else {
            let target = ScreenCaptureAudioPermission.permissionTarget
            lastMessage = "Open System Settings, add \(target.displayName) if needed, and toggle it on."
            openSettings()
            startPolling()
            schedulePermissionRefresh()
        }
    }

    private func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.check()
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        burstRefreshTask?.cancel()
        burstRefreshTask = nil
        refreshInFlight = false
    }

    nonisolated private static func runTccutilReset(service: String, bundleId: String) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", service, bundleId]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return (process.terminationStatus, output)
        } catch {
            return (1, error.localizedDescription)
        }
    }
}

@MainActor
final class ScreenCaptureAudioPermissionWindowController: ObservableObject {
    static let shared = ScreenCaptureAudioPermissionWindowController()

    private var window: NSWindow?

    var isVisible: Bool { window?.isVisible ?? false }

    func show(startRequest: Bool = false) {
        ScreenCaptureAudioPermissionChecker.shared.check()

        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            if startRequest {
                ScreenCaptureAudioPermissionChecker.shared.requestScreenAudio()
            }
            return
        }

        let view = ScreenCaptureAudioPermissionAssistantView(
            onClose: { ScreenCaptureAudioPermissionWindowController.shared.close() }
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 430),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pomo Amp Visualizer Options"
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(red: 0.055, green: 0.058, blue: 0.058, alpha: 1)
        window.contentViewController = NSHostingController(rootView: view)
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        if startRequest {
            ScreenCaptureAudioPermissionChecker.shared.requestScreenAudio()
        }
    }

    func close() {
        window?.orderOut(nil)
    }
}

private struct ScreenCaptureAudioPermissionAssistantView: View {
    @ObservedObject private var checker = ScreenCaptureAudioPermissionChecker.shared
    private static let checkTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    var onClose: () -> Void

    private let accent = Color(red: 0.51, green: 0.90, blue: 0.69)
    private let amber = Color(red: 0.96, green: 0.58, blue: 0.34)
    private let panel = Color(red: 0.08, green: 0.085, blue: 0.08)
    private let surface = Color.white.opacity(0.065)
    private let line = Color.white.opacity(0.12)

    var body: some View {
        VStack(spacing: 0) {
            header

            Rectangle()
                .fill(line)
                .frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    valueCard
                    statusCard
                    dragCard
                    actions
                }
                .padding(18)
            }
        }
        .frame(minWidth: 620, minHeight: 410)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.08, blue: 0.075),
                    Color(red: 0.035, green: 0.038, blue: 0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .foregroundStyle(Color.white.opacity(0.92))
        .preferredColorScheme(.dark)
        .onAppear {
            checker.check()
        }
        .task {
            while !Task.isCancelled {
                checker.check()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill((checker.granted ? accent : amber).opacity(0.16))
                    .frame(width: 42, height: 42)
                Image(systemName: checker.granted ? "waveform.badge.checkmark" : "waveform.badge.exclamationmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(checker.granted ? accent : amber)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Pomo Amp Visualizer")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                Text(ScreenCaptureAudioPermission.requirementLabel)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.52))
            }

            Spacer()

            statusBadge

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .frame(width: 24, height: 24)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.065)))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
    }

    private var statusBadge: some View {
        Text(checker.granted ? "ON" : (checker.refreshInFlight ? "CHECKING" : "OFF"))
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .foregroundStyle(checker.granted ? accent : amber)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill((checker.granted ? accent : amber).opacity(0.13)))
    }

    private var valueCard: some View {
        sectionCard(title: "OPTIONAL AUDIO VISUALIZER") {
            VStack(alignment: .leading, spacing: 7) {
                Text("Pomo Amp can animate from lightweight fallback motion, or optionally analyze live system audio when YouTube blocks Web Audio.")
                    .font(.system(size: 12, weight: .medium))
                    .lineSpacing(3)
                Text("Playback works without this. If enabled, Pomo Amp reads short-lived audio samples for bands and waveform only; it does not save audio or screen video.")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.54))
            }
        }
    }

    private var statusCard: some View {
        sectionCard(title: "STATUS") {
            HStack(spacing: 9) {
                Image(systemName: checker.granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(checker.granted ? accent : amber)
                Text(statusMessage)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.86))
                Spacer()
            }
        }
    }

    private var statusMessage: String {
        if checker.granted {
            return "Visualizer audio capture is enabled."
        }
        if checker.refreshInFlight {
            return "Checking macOS permission state..."
        }
        if let message = checker.lastMessage {
            return message
        }
        if let lastCheckedAt = checker.lastCheckedAt {
            return "Last checked \(Self.checkTimeFormatter.string(from: lastCheckedAt)); macOS still reports disabled."
        }
        return "Not enabled. Pomo Amp works without it and will use quiet fallback visuals."
    }

    private var dragCard: some View {
        sectionCard(title: "IF SETTINGS SHOWS AN OLD ENTRY") {
            let target = ScreenCaptureAudioPermission.permissionTarget
            HStack(alignment: .center, spacing: 14) {
                PomoAmpPermissionAppDragTile(
                    appURL: target.appURL,
                    appIcon: NSWorkspace.shared.icon(forFile: target.path),
                    permissionName: ScreenCaptureAudioPermission.requirementLabel,
                    isDragEnabled: !checker.granted,
                    onDragStarted: {
                        ScreenCaptureAudioPermission.registerPermissionTarget(reason: "drag started")
                        checker.passiveRecheck(reason: "drag started")
                    },
                    onDragCompleted: {
                        checker.recheckNow(reason: "drag completed")
                    }
                )
                .frame(width: 92, height: 92)

                VStack(alignment: .leading, spacing: 5) {
                    Text(checker.granted ? "\(target.displayName) is enabled" : "Add the running \(target.displayName) app")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                    Text("If macOS shows an older row, remove it first. Then drag this exact app into Screen & System Audio Recording and toggle it on.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.58))
                        .lineSpacing(2)
                    Text(target.bundleIdentifier.isEmpty ? target.path : "\(target.bundleIdentifier)  \(target.path)")
                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.42))
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 9) {
            Button {
                checker.requestScreenAudio()
            } label: {
                Label(checker.granted ? "Enabled" : "Enable Visualizer", systemImage: checker.granted ? "checkmark.circle.fill" : "waveform")
            }
            .disabled(checker.granted || checker.refreshInFlight)

            Button {
                checker.openSettings()
            } label: {
                Label("Open Settings", systemImage: "gearshape")
            }

            Button {
                ScreenCaptureAudioPermission.registerPermissionTarget(reason: "reveal app")
                NSWorkspace.shared.activateFileViewerSelecting([ScreenCaptureAudioPermission.permissionTarget.appURL])
            } label: {
                Label("Reveal App", systemImage: "folder")
            }

            Button {
                checker.recheckNow(reason: "assistant")
            } label: {
                Label(checker.refreshInFlight ? "Checking" : "Check Again", systemImage: "checkmark.shield")
            }
            .disabled(checker.refreshInFlight)

            if !checker.granted {
                Button {
                    checker.resetSavedApproval()
                } label: {
                    Label("Clear Row", systemImage: "trash")
                }
                .help("Clears the saved macOS audio-capture permission row for this app bundle id.")
            }

            Spacer()

            if checker.granted {
                Button("Done") {
                    onClose()
                }
                .keyboardShortcut(.defaultAction)
            } else {
                Button {
                    checker.quitAndRelaunch()
                } label: {
                    Label("Relaunch", systemImage: "arrow.clockwise.circle")
                }
                .help("Screen & System Audio Recording often becomes usable after the app restarts.")
            }
        }
        .buttonStyle(.bordered)
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(Color.white.opacity(0.42))
            content()
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(surface)
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(line, lineWidth: 1))
        )
    }
}

private struct PomoAmpPermissionAppDragTile: NSViewRepresentable {
    let appURL: URL
    let appIcon: NSImage
    let permissionName: String
    var isDragEnabled: Bool = true
    var onDragStarted: () -> Void = {}
    var onDragCompleted: () -> Void = {}

    func makeNSView(context: Context) -> PomoAmpPermissionAppDragTileView {
        PomoAmpPermissionAppDragTileView(
            appURL: appURL,
            appIcon: appIcon,
            permissionName: permissionName,
            isDragEnabled: isDragEnabled,
            onDragStarted: onDragStarted,
            onDragCompleted: onDragCompleted
        )
    }

    func updateNSView(_ nsView: PomoAmpPermissionAppDragTileView, context: Context) {
        nsView.appURL = appURL
        nsView.appIcon = appIcon
        nsView.permissionName = permissionName
        nsView.isDragEnabled = isDragEnabled
        nsView.onDragStarted = onDragStarted
        nsView.onDragCompleted = onDragCompleted
    }
}

private final class PomoAmpPermissionAppDragTileView: NSView, NSDraggingSource {
    var appURL: URL { didSet { updateToolTip(); needsDisplay = true } }
    var appIcon: NSImage { didSet { needsDisplay = true } }
    var permissionName: String { didSet { updateToolTip() } }
    var isDragEnabled: Bool { didSet { updateToolTip(); discardCursorRects(); needsDisplay = true } }
    var onDragStarted: () -> Void
    var onDragCompleted: () -> Void

    private var dragStartLocation: NSPoint?
    private var isDragging = false
    private let dragThreshold: CGFloat = 4

    init(
        appURL: URL,
        appIcon: NSImage,
        permissionName: String,
        isDragEnabled: Bool,
        onDragStarted: @escaping () -> Void,
        onDragCompleted: @escaping () -> Void
    ) {
        self.appURL = appURL
        self.appIcon = appIcon
        self.permissionName = permissionName
        self.isDragEnabled = isDragEnabled
        self.onDragStarted = onDragStarted
        self.onDragCompleted = onDragCompleted
        super.init(frame: .zero)
        updateToolTip()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let accent = NSColor(calibratedRed: 0.51, green: 0.90, blue: 0.69, alpha: isDragEnabled ? 1 : 0.42)
        let amber = NSColor(calibratedRed: 0.96, green: 0.58, blue: 0.34, alpha: isDragEnabled ? 1 : 0.42)
        let tint = isDragEnabled ? amber : accent
        let fill = NSColor(calibratedWhite: 0.08, alpha: 0.96)
        let cardRect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 7, yRadius: 7)

        fill.setFill()
        cardPath.fill()

        let iconSize = min(bounds.width, bounds.height) * 0.50
        let iconRect = NSRect(
            x: (bounds.width - iconSize) / 2,
            y: 15,
            width: iconSize,
            height: iconSize
        )
        appIcon.draw(
            in: iconRect,
            from: NSRect(origin: .zero, size: appIcon.size),
            operation: .sourceOver,
            fraction: isDragEnabled ? 1 : 0.45,
            respectFlipped: true,
            hints: nil
        )

        if let symbol = NSImage(
            systemSymbolName: isDragEnabled ? "hand.draw" : "checkmark.circle.fill",
            accessibilityDescription: isDragEnabled ? "Drag" : "Granted"
        )?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)) {
            let symbolSize = NSSize(width: 17, height: 17)
            let symbolRect = NSRect(
                x: (bounds.width - symbolSize.width) / 2,
                y: iconRect.maxY + 5,
                width: symbolSize.width,
                height: symbolSize.height
            )
            symbol.isTemplate = true
            tint.set()
            symbol.draw(in: symbolRect)
        }

        drawStatusLabel(isDragEnabled ? "DRAG ME" : "GRANTED", color: tint)

        var dash: [CGFloat] = [5, 4]
        cardPath.setLineDash(&dash, count: dash.count, phase: 0)
        cardPath.lineWidth = isDragEnabled ? 1.2 : 1
        tint.withAlphaComponent(isDragEnabled ? 0.72 : 0.35).setStroke()
        cardPath.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        guard isDragEnabled else { return }
        window?.makeKey()
        _ = window?.makeFirstResponder(self)
        dragStartLocation = convert(event.locationInWindow, from: nil)
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragEnabled, !isDragging, let startLocation = dragStartLocation else { return }

        let currentLocation = convert(event.locationInWindow, from: nil)
        let dx = currentLocation.x - startLocation.x
        let dy = currentLocation.y - startLocation.y
        guard sqrt(dx * dx + dy * dy) >= dragThreshold else { return }

        startDrag(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        dragStartLocation = nil
        isDragging = false
    }

    override func resetCursorRects() {
        if isDragEnabled {
            addCursorRect(bounds, cursor: .openHand)
        }
    }

    private func startDrag(with event: NSEvent) {
        isDragging = true
        dragStartLocation = nil
        onDragStarted()

        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(appURL.absoluteString, forType: .fileURL)
        pasteboardItem.setString(appURL.absoluteString, forType: .URL)
        pasteboardItem.setString(appURL.path, forType: .string)

        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        let imageSize = NSSize(width: 64, height: 64)
        let imageFrame = NSRect(
            x: bounds.midX - imageSize.width / 2,
            y: bounds.midY - imageSize.height / 2,
            width: imageSize.width,
            height: imageSize.height
        )
        draggingItem.setDraggingFrame(imageFrame, contents: appIcon)

        let session = beginDraggingSession(with: [draggingItem], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        isDragging = false
        dragStartLocation = nil
        onDragCompleted()
    }

    private func drawStatusLabel(_ label: String, color: NSColor) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let labelFont = NSFont(name: "Menlo-Bold", size: 8.5)
            ?? NSFont.systemFont(ofSize: 8.5, weight: .semibold)
        let attributed = NSAttributedString(
            string: label,
            attributes: [
                .font: labelFont,
                .foregroundColor: color,
                .paragraphStyle: paragraphStyle,
            ]
        )
        attributed.draw(
            in: NSRect(
                x: 0,
                y: bounds.height - 20,
                width: bounds.width,
                height: 12
            )
        )
    }

    private func updateToolTip() {
        toolTip = isDragEnabled
            ? "Drag \(appURL.lastPathComponent) into \(permissionName)"
            : "\(permissionName) is enabled"
    }
}
