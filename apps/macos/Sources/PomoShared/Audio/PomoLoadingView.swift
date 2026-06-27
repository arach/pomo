import AppKit

/// A Pomo-branded loading overlay for the video drawer. While a cold YouTube
/// player warms up (white flash + page assembling), this opaque, shimmering
/// placeholder sits on top — the ring mark pulses and a brand-yellow band sweeps
/// across — so the wait reads as intentional. It fades out once the video is
/// actually rendering.
final class PomoLoadingView: NSView {
    private let shimmer = CAGradientLayer()
    private let mark = CALayer()
    private static let brand = NSColor(srgbRed: 234.0 / 255, green: 228.0 / 255, blue: 52.0 / 255, alpha: 1)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor(srgbRed: 0.055, green: 0.047, blue: 0.043, alpha: 1).cgColor // #0e0c0b

        shimmer.colors = [
            NSColor.white.withAlphaComponent(0).cgColor,
            Self.brand.withAlphaComponent(0.10).cgColor,
            NSColor.white.withAlphaComponent(0).cgColor,
        ]
        shimmer.locations = [0, 0.5, 1]
        shimmer.startPoint = CGPoint(x: 0, y: 0.35)
        shimmer.endPoint = CGPoint(x: 1, y: 0.65)
        layer?.addSublayer(shimmer)

        mark.contents = Self.ringMark()
        mark.contentsGravity = .resizeAspect
        layer?.addSublayer(mark)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        shimmer.frame = bounds
        let s: CGFloat = 34
        mark.frame = CGRect(x: (bounds.width - s) / 2, y: (bounds.height - s) / 2, width: s, height: s)
    }

    func start() {
        let sweep = CABasicAnimation(keyPath: "locations")
        sweep.fromValue = [-0.6, -0.1, 0.4]
        sweep.toValue = [0.6, 1.1, 1.6]
        sweep.duration = 1.2
        sweep.repeatCount = .infinity
        sweep.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        shimmer.add(sweep, forKey: "sweep")

        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 0.5
        pulse.toValue = 1.0
        pulse.duration = 0.95
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        mark.add(pulse, forKey: "pulse")
    }

    func stop() {
        shimmer.removeAllAnimations()
        mark.removeAllAnimations()
    }

    /// The Pomo ring mark — faint ring, brand-yellow progress arc + dot, top tick.
    private static func ringMark() -> NSImage {
        NSImage(size: NSSize(width: 68, height: 68), flipped: false) { _ in
            let c = NSPoint(x: 34, y: 34)
            let r: CGFloat = 24

            let ring = NSBezierPath()
            ring.appendArc(withCenter: c, radius: r, startAngle: 0, endAngle: 360)
            ring.lineWidth = 3
            NSColor.white.withAlphaComponent(0.22).setStroke()
            ring.stroke()

            let arc = NSBezierPath()
            arc.appendArc(withCenter: c, radius: r, startAngle: 90, endAngle: 0, clockwise: true)
            arc.lineWidth = 4
            arc.lineCapStyle = .round
            brand.setStroke()
            arc.stroke()

            let tick = NSBezierPath()
            tick.move(to: NSPoint(x: c.x, y: c.y + r + 6))
            tick.line(to: NSPoint(x: c.x, y: c.y + r - 1))
            tick.lineWidth = 3
            tick.lineCapStyle = .round
            NSColor.white.withAlphaComponent(0.8).setStroke()
            tick.stroke()

            let dotR: CGFloat = 4
            brand.setFill()
            NSBezierPath(ovalIn: NSRect(x: c.x - dotR, y: c.y - dotR, width: dotR * 2, height: dotR * 2)).fill()
            return true
        }
    }
}
