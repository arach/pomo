import CoreGraphics
import Observation

@MainActor
@Observable
final class PomoAmpChrome {
    static let titleBarHeight: CGFloat = 30
    static let shadeBarHeight: CGFloat = 56

    var showShortcuts = false
    var showVizInspector = false
    var isBig = false
    var isRolledUp = false
    var panelSize: CGSize

    init(panelSize: CGSize) {
        self.panelSize = panelSize
    }
}
