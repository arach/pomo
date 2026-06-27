import AppKit
import SwiftUI

/// Blurs the desktop *behind* the window by a tunable Gaussian radius — the
/// macOS equivalent of CSS `backdrop-filter: blur()`. Unlike `NSVisualEffectView`
/// it adds no light tint, so raising the radius hides detail behind the panel
/// without washing it white.
///
/// Built on CoreAnimation's `CABackdropLayer` + a `gaussianBlur` `CAFilter`.
/// Both are private API — acceptable for a self-distributed app, not App-Store
/// safe — so everything is resolved at runtime and degrades to a clear no-op if
/// the classes ever go away.
struct BackdropBlurView: NSViewRepresentable {
    /// Gaussian blur radius in points (0 = sharp desktop showing through).
    var radius: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = BackdropHostView()
        view.blurRadius = radius
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? BackdropHostView)?.blurRadius = radius
    }
}

private final class BackdropHostView: NSView {
    var blurRadius: CGFloat = 0 {
        didSet { applyRadius() }
    }

    override func makeBackingLayer() -> CALayer {
        if let backdropClass = NSClassFromString("CABackdropLayer") as? CALayer.Type {
            return backdropClass.init()
        }
        return super.makeBackingLayer()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        applyRadius()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layout() {
        super.layout()
        layer?.frame = bounds
    }

    private func applyRadius() {
        guard let layer else { return }
        guard blurRadius > 0.01, let blur = Self.gaussianBlurFilter() else {
            layer.filters = nil
            return
        }
        blur.setValue(NSNumber(value: Double(blurRadius)), forKey: "inputRadius")
        blur.setValue(NSNumber(value: true), forKey: "inputNormalizeEdges")
        layer.filters = [blur]
    }

    /// Resolve the private `+[CAFilter filterWithName:]` at runtime.
    private static func gaussianBlurFilter() -> NSObject? {
        guard let filterClass = NSClassFromString("CAFilter") else { return nil }
        let selector = NSSelectorFromString("filterWithName:")
        guard (filterClass as AnyObject).responds(to: selector) else { return nil }
        let result = (filterClass as AnyObject).perform(selector, with: "gaussianBlur")
        return result?.takeUnretainedValue() as? NSObject
    }
}
