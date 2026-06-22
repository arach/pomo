import SwiftUI
import HudsonUI

/// A tiny, guided panel for borrowing a YouTube login from a browser the user is
/// already signed into — so the web player goes ad-free (Premium) without a fresh
/// sign-in. Pick a browser, we read its cookies via the `pomo-cookies` helper,
/// then confirm the identity off the reloaded page.
///
/// Three states: choose a browser → working → result (signed-in / nothing found).
/// Follows the system light/dark appearance via `AppPalette`, like Settings.
struct CookieImportPanel: View {
    var account: AccountStatus
    /// Imports auth cookies from the given browser id; returns how many it found.
    var onImport: (String) async -> Int
    var onClose: () -> Void

    private struct Browser: Identifiable {
        let id: String
        let name: String
        let note: String?
    }

    private let browsers: [Browser] = [
        .init(id: "chrome",  name: "Chrome",  note: "Keychain prompt"),
        .init(id: "brave",   name: "Brave",   note: "Keychain prompt"),
        .init(id: "arc",     name: "Arc",     note: nil),
        .init(id: "edge",    name: "Edge",    note: nil),
        .init(id: "firefox", name: "Firefox", note: nil),
        .init(id: "safari",  name: "Safari",  note: "Full Disk Access"),
    ]

    private enum Phase { case choose, working, done }
    @State private var phase: Phase = .choose
    @State private var pickedName = ""
    @State private var importedCount = 0
    @State private var confirmed = false
    @State private var hovered: String?

    @Environment(\.colorScheme) private var scheme
    private var pal: AppPalette { .resolve(scheme) }

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
        .frame(width: 360)
        .background(pal.bg)
    }

    private var header: some View {
        HStack(spacing: HudSpacing.md) {
            Image(systemName: "key.horizontal.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(pal.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("Import YouTube Login")
                    .font(HudFont.mono(HudTextSize.md, weight: .semibold))
                    .foregroundStyle(pal.ink)
                Text("Go ad-free with a session you already have")
                    .font(HudFont.ui(HudTextSize.xs))
                    .foregroundStyle(pal.dim)
            }
        }
    }

    // MARK: - Step 1 · choose

    private var chooseStep: some View {
        VStack(alignment: .leading, spacing: HudSpacing.lg) {
            Text("Borrow the login from a browser you're already signed into — the player goes ad-free with Premium.")
                .font(HudFont.ui(HudTextSize.xs))
                .foregroundStyle(pal.muted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: HudSpacing.sm) {
                ForEach(browsers) { browser in
                    browserRow(browser)
                }
            }

            HStack {
                Spacer()
                button("Cancel", action: onClose)
            }
        }
    }

    private func browserRow(_ browser: Browser) -> some View {
        let isHovered = hovered == browser.id
        return Button { start(browser) } label: {
            HStack(spacing: HudSpacing.md) {
                Image(systemName: "globe")
                    .font(HudFont.ui(HudTextSize.sm))
                    .foregroundStyle(isHovered ? pal.action : pal.muted)
                    .frame(width: 18)
                Text(browser.name)
                    .font(HudFont.ui(HudTextSize.sm, weight: .medium))
                    .foregroundStyle(pal.ink)
                Spacer()
                if let note = browser.note {
                    Text(note)
                        .font(HudFont.mono(HudTextSize.micro))
                        .foregroundStyle(pal.dim)
                }
                Image(systemName: "chevron.right")
                    .font(HudFont.ui(HudTextSize.micro, weight: .semibold))
                    .foregroundStyle(pal.dim)
            }
            .padding(.horizontal, HudSpacing.lg)
            .frame(height: 40)
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
        .onHover { hovered = $0 ? browser.id : (hovered == browser.id ? nil : hovered) }
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
            Text("Chrome-based browsers may ask for Keychain access.")
                .font(HudFont.ui(HudTextSize.xs))
                .foregroundStyle(pal.dim)
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
                Label("Ad-free with Premium", systemImage: "checkmark.seal.fill")
                    .font(HudFont.ui(HudTextSize.xs, weight: .medium))
                    .foregroundStyle(pal.action)
                button("Done", kind: .primary, action: onClose)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HudSpacing.lg)
        } else {
            VStack(alignment: .leading, spacing: HudSpacing.lg) {
                Label(
                    importedCount > 0
                        ? "Imported \(importedCount) cookies from \(pickedName), but couldn't confirm the sign-in."
                        : "No YouTube login found in \(pickedName).",
                    systemImage: importedCount > 0 ? "exclamationmark.triangle.fill" : "xmark.circle.fill"
                )
                .font(HudFont.ui(HudTextSize.sm))
                .foregroundStyle(pal.muted)
                .fixedSize(horizontal: false, vertical: true)

                Text(importedCount > 0
                    ? "Try playing a video — the page may still be signing in."
                    : "Make sure you're logged into YouTube in that browser, or pick another.")
                    .font(HudFont.ui(HudTextSize.xs))
                    .foregroundStyle(pal.dim)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    button("Try another") { phase = .choose }
                    Spacer()
                    button("Close", action: onClose)
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

    private func start(_ browser: Browser) {
        pickedName = browser.name
        confirmed = false
        importedCount = 0
        phase = .working
        Task {
            let count = await onImport(browser.id)
            importedCount = count
            // The reload + masthead read is async; give it a moment to confirm.
            if count > 0 {
                for _ in 0..<24 where !account.signedIn {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                }
            }
            confirmed = account.signedIn
            phase = .done
        }
    }
}
