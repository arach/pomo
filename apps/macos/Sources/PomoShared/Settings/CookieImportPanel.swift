import SwiftUI
import HudsonUI

/// A tiny, guided panel for borrowing a web-player login from a browser the user
/// is already signed into. Chromium-family browsers expose multiple profiles, so
/// we make those choices explicit instead of importing from an ambiguous default.
struct CookieImportPanel: View {
    var service: AuthService = .youTube
    var account: AccountStatus
    var profiles: [CookieImporter.BrowserProfile]
    /// Imports auth cookies from the given browser/profile; returns how many it found.
    var onImport: (String, String?, Int) async -> Int
    var onClose: () -> Void

    private struct Browser: Identifiable {
        let id: String
        let name: String
        let note: String?
    }

    private struct ImportTarget: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let note: String?
        let icon: String
        let browser: String
        let profile: String?

        var workingName: String {
            profile == nil ? title : "\(subtitle) / \(title)"
        }
    }

    private let fallbackBrowsers: [Browser] = [
        .init(id: "safari", name: "Safari", note: "Full Disk Access"),
        .init(id: "firefox", name: "Firefox", note: nil),
        .init(id: "arc", name: "Arc", note: nil),
    ]

    private var profileTargets: [ImportTarget] {
        profiles.map { profile in
            ImportTarget(
                id: "profile-\(profile.id)",
                title: profile.title,
                subtitle: profile.subtitle,
                note: profile.note,
                icon: "person.crop.circle",
                browser: profile.browser,
                profile: profile.profile
            )
        }
    }

    private var browserTargets: [ImportTarget] {
        fallbackBrowsers.map { browser in
            ImportTarget(
                id: "browser-\(browser.id)",
                title: browser.name,
                subtitle: "Browser default",
                note: browser.note,
                icon: "globe",
                browser: browser.id,
                profile: nil
            )
        }
    }

    private enum Phase { case choose, working, done }
    @State private var phase: Phase = .choose
    @State private var pickedName = ""
    @State private var importedCount = 0
    @State private var confirmed = false
    @State private var hovered: String?
    @State private var selectedAccountIndex = 0

    @Environment(\.colorScheme) private var scheme
    private var pal: AppPalette { .resolve(scheme) }
    private let accountSlots = Array(0...3)

    var body: some View {
        VStack(alignment: .leading, spacing: HudSpacing.xl) {
            header
            switch phase {
            case .choose:  chooseStep
            case .working: workingStep
            case .done:    resultStep
            }
        }
        .padding(HudSpacing.huge)
        .frame(width: 388)
        .background(pal.bg)
    }

    private var header: some View {
        HStack(spacing: HudSpacing.md) {
            Image(systemName: "key.horizontal.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(pal.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("Import \(service.displayName) Login")
                    .font(HudFont.mono(HudTextSize.md, weight: .semibold))
                    .foregroundStyle(pal.ink)
                Text("Choose the browser profile signed into \(service.displayName)")
                    .font(HudFont.ui(HudTextSize.xs))
                    .foregroundStyle(pal.dim)
            }
        }
    }

    // MARK: - Step 1 · choose

    private var chooseStep: some View {
        VStack(alignment: .leading, spacing: HudSpacing.lg) {
            Text("Pick the same profile you use for \(service.displayName). Chrome-based browsers may ask for Keychain access.")
                .font(HudFont.ui(HudTextSize.xs))
                .foregroundStyle(pal.muted)
                .fixedSize(horizontal: false, vertical: true)

            if service == .youTube {
                accountPicker
            }

            ScrollView {
                VStack(alignment: .leading, spacing: HudSpacing.md) {
                    if !profileTargets.isEmpty {
                        sectionLabel("Detected Profiles")
                        VStack(spacing: HudSpacing.sm) {
                            ForEach(profileTargets) { target in
                                targetRow(target)
                            }
                        }
                    }

                    if !browserTargets.isEmpty {
                        sectionLabel(profileTargets.isEmpty ? "Browsers" : "Other Browsers")
                            .padding(.top, profileTargets.isEmpty ? 0 : HudSpacing.sm)
                        VStack(spacing: HudSpacing.sm) {
                            ForEach(browserTargets) { target in
                                targetRow(target)
                            }
                        }
                    }
                }
                .padding(.vertical, 1)
            }
            .frame(height: 292)

            HStack {
                Spacer()
                button("Cancel", action: onClose)
            }
        }
    }

    private var accountPicker: some View {
        VStack(alignment: .leading, spacing: HudSpacing.sm) {
            sectionLabel("Google Account")
            Picker("", selection: $selectedAccountIndex) {
                ForEach(accountSlots, id: \.self) { index in
                    Text(accountLabel(index)).tag(index)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    private func accountLabel(_ index: Int) -> String {
        index == 0 ? "Default" : "\(index + 1)"
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(HudFont.mono(HudTextSize.micro, weight: .bold))
            .foregroundStyle(pal.dim)
            .tracking(1.6)
    }

    private func targetRow(_ target: ImportTarget) -> some View {
        let isHovered = hovered == target.id
        return Button { start(target) } label: {
            HStack(spacing: HudSpacing.md) {
                Image(systemName: target.icon)
                    .font(HudFont.ui(HudTextSize.sm))
                    .foregroundStyle(isHovered ? pal.action : pal.muted)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(target.title)
                        .font(HudFont.ui(HudTextSize.sm, weight: .medium))
                        .foregroundStyle(pal.ink)
                        .lineLimit(1)
                    Text(target.subtitle)
                        .font(HudFont.ui(HudTextSize.xs))
                        .foregroundStyle(pal.dim)
                        .lineLimit(1)
                }

                Spacer(minLength: HudSpacing.md)

                if let note = target.note {
                    Text(note)
                        .font(HudFont.mono(HudTextSize.micro))
                        .foregroundStyle(pal.dim)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(HudFont.ui(HudTextSize.micro, weight: .semibold))
                    .foregroundStyle(pal.dim)
            }
            .padding(.horizontal, HudSpacing.lg)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: HudRadius.standard)
                    .fill(isHovered ? pal.surfaceHover : pal.inset)
                    .overlay(
                        RoundedRectangle(cornerRadius: HudRadius.standard)
                            .stroke(isHovered ? pal.action.opacity(0.5) : pal.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 ? target.id : (hovered == target.id ? nil : hovered) }
    }

    // MARK: - Step 2 · working

    private var workingStep: some View {
        VStack(spacing: HudSpacing.lg) {
            ProgressView()
                .controlSize(.large)
                .tint(pal.action)
            Text("Reading your login from \(pickedName)…")
                .font(HudFont.ui(HudTextSize.sm))
                .foregroundStyle(pal.muted)
                .multilineTextAlignment(.center)
            Text("If macOS asks for access, approve the browser's cookie/keychain prompt.")
                .font(HudFont.ui(HudTextSize.xs))
                .foregroundStyle(pal.dim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, HudSpacing.xxl)
    }

    // MARK: - Step 3 · result

    @ViewBuilder private var resultStep: some View {
        if confirmed {
            VStack(spacing: HudSpacing.lg) {
                avatar
                Text("Signed in as \(account.name ?? "your account")")
                    .font(HudFont.ui(HudTextSize.sm, weight: .semibold))
                    .foregroundStyle(pal.ink)
                if service == .youTube {
                    Label("Ad-free with Premium", systemImage: "checkmark.seal.fill")
                        .font(HudFont.ui(HudTextSize.xs, weight: .medium))
                        .foregroundStyle(pal.action)
                } else {
                    Label("Signed in for playlists and library", systemImage: "checkmark.seal.fill")
                        .font(HudFont.ui(HudTextSize.xs, weight: .medium))
                        .foregroundStyle(pal.action)
                }
                button("Done", kind: .primary, action: onClose)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HudSpacing.lg)
        } else {
            VStack(alignment: .leading, spacing: HudSpacing.lg) {
                Label(
                    importedCount > 0
                        ? "Imported \(importedCount) cookies from \(pickedName)."
                        : "No \(service.displayName) login found in \(pickedName).",
                    systemImage: importedCount > 0 ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(HudFont.ui(HudTextSize.sm))
                .foregroundStyle(importedCount > 0 ? pal.action : pal.muted)
                .fixedSize(horizontal: false, vertical: true)

                if importedCount == 0 {
                    Text("Make sure you're logged into \(service.displayName) in that profile, or pick another.")
                        .font(HudFont.ui(HudTextSize.xs))
                        .foregroundStyle(pal.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    if importedCount == 0 {
                        button("Try another") { phase = .choose }
                    }
                    Spacer()
                    button(importedCount > 0 ? "Done" : "Close", action: onClose)
                }
            }
        }
    }

    @ViewBuilder private var avatar: some View {
        Group {
            if let img = account.avatar {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable().aspectRatio(contentMode: .fit)
                    .foregroundStyle(pal.action)
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
        .overlay(Circle().stroke(pal.border, lineWidth: 1))
    }

    // MARK: - Button

    private enum ButtonKind { case primary, secondary }

    private func button(_ title: String, kind: ButtonKind = .secondary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(HudFont.mono(HudTextSize.xs, weight: .semibold))
                .foregroundStyle(kind == .primary ? Color.black.opacity(0.82) : pal.ink)
                .padding(.horizontal, HudSpacing.lg)
                .padding(.vertical, HudSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: HudRadius.standard)
                        .fill(kind == .primary ? pal.action : pal.inset)
                        .overlay(
                            RoundedRectangle(cornerRadius: HudRadius.standard)
                                .stroke(kind == .primary ? Color.clear : pal.border, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Flow

    private func start(_ target: ImportTarget) {
        pickedName = target.workingName
        confirmed = false
        importedCount = 0
        phase = .working
        Task {
            let count = await onImport(target.browser, target.profile, service == .youTube ? selectedAccountIndex : 0)
            importedCount = count
            if count > 0 {
                if service == .youTube {
                    // YouTube identity is read off the page masthead after reload.
                    for _ in 0..<24 where !account.signedIn {
                        try? await Task.sleep(nanoseconds: 250_000_000)
                    }
                    confirmed = account.signedIn
                } else {
                    confirmed = account.signedIn || count > 0
                }
            } else {
                confirmed = false
            }
            phase = .done
        }
    }
}
