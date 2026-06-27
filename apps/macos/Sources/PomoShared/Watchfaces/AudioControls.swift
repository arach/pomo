import SwiftUI

/// State + actions for the on-face audio controls — a play/pause for the
/// background music and a show/hide for the attached video drawer. Injected by
/// `HUDRootView` through the environment so the shared `FaceControls` row can
/// render the two extra buttons without every watchface having to thread audio
/// state through its own signature.
///
/// The buttons only appear when `enabled` (a station is configured or playing).
struct AudioFaceControls {
    var enabled: Bool = false
    var isPlaying: Bool = false
    var drawerOpen: Bool = false
    var togglePlay: () -> Void = {}
    var toggleDrawer: () -> Void = {}
}

private struct AudioFaceControlsKey: EnvironmentKey {
    static let defaultValue = AudioFaceControls()
}

extension EnvironmentValues {
    var audioControls: AudioFaceControls {
        get { self[AudioFaceControlsKey.self] }
        set { self[AudioFaceControlsKey.self] = newValue }
    }
}
