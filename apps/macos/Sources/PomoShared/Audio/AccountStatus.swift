import AppKit
import Observation

/// Observable snapshot of the signed-in YouTube identity, shared by the player,
/// the Settings account row, and the drawer's avatar affordance. Populated from
/// the page after each load; cleared on sign-out.
@MainActor
@Observable
final class AccountStatus {
    var signedIn = false
    var name: String?
    var avatar: NSImage?
}
