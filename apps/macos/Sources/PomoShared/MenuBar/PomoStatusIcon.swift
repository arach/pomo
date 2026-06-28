import AppKit

enum PomoStatusIcon {
    static func timerRing(
        progress rawProgress: Double = 0,
        isPaused: Bool = false,
        isIdle: Bool = true,
        size: CGFloat = 18
    ) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let scale = min(rect.width, rect.height) / 18
            let origin = NSPoint(
                x: rect.midX - 9 * scale,
                y: rect.midY - 9 * scale
            )
            func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
                NSPoint(x: origin.x + x * scale, y: origin.y + y * scale)
            }

            let progress = CGFloat(max(0, min(1, rawProgress)))
            let center = point(9, 9)
            let radius: CGFloat = 6 * scale

            let ring = NSBezierPath()
            ring.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            ring.lineWidth = 1.3 * scale
            NSColor.black.withAlphaComponent(isIdle ? 0.42 : 0.24).setStroke()
            ring.stroke()

            if !isIdle {
                let arc = NSBezierPath()
                let capped = min(progress, 0.999)
                arc.appendArc(
                    withCenter: center,
                    radius: radius,
                    startAngle: 90,
                    endAngle: 90 - capped * 360,
                    clockwise: true
                )
                arc.lineWidth = 1.9 * scale
                arc.lineCapStyle = .round
                NSColor.black.withAlphaComponent(isPaused ? 0.62 : 1.0).setStroke()
                arc.stroke()
            }

            let tick = NSBezierPath()
            tick.move(to: point(9, 16.8))
            tick.line(to: point(9, 14.6))
            tick.lineWidth = 1.5 * scale
            tick.lineCapStyle = .round
            NSColor.black.setStroke()
            tick.stroke()

            let dotRadius: CGFloat = 1.4 * scale
            let dotRect = NSRect(
                x: center.x - dotRadius,
                y: center.y - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            )
            NSColor.black.setFill()
            NSBezierPath(ovalIn: dotRect).fill()

            return true
        }
        image.isTemplate = true
        return image
    }

    static func ampPlayClock(active: Bool, size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let scale = min(rect.width, rect.height) / 18
            let origin = NSPoint(
                x: rect.midX - 9 * scale,
                y: rect.midY - 9 * scale
            )
            func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
                NSPoint(x: origin.x + x * scale, y: origin.y + y * scale)
            }

            let center = point(9, 9)
            let radius: CGFloat = 6 * scale
            let alpha = active ? 1.0 : 0.58

            let ring = NSBezierPath()
            ring.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            ring.lineWidth = 1.45 * scale
            NSColor.black.withAlphaComponent(alpha).setStroke()
            ring.stroke()

            let tick = NSBezierPath()
            tick.move(to: point(9, 16.8))
            tick.line(to: point(9, 14.6))
            tick.lineWidth = 1.45 * scale
            tick.lineCapStyle = .round
            NSColor.black.withAlphaComponent(alpha).setStroke()
            tick.stroke()

            let play = NSBezierPath()
            play.move(to: point(7.25, 5.7))
            play.line(to: point(7.25, 12.3))
            play.line(to: point(12.4, 9))
            play.close()
            NSColor.black.withAlphaComponent(active ? 1.0 : 0.7).setFill()
            play.fill()

            if active {
                let dotRadius: CGFloat = 1.55 * scale
                let dotCenter = point(14.35, 4.25)
                let dotRect = NSRect(
                    x: dotCenter.x - dotRadius,
                    y: dotCenter.y - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                )
                NSColor.black.setFill()
                NSBezierPath(ovalIn: dotRect).fill()
            }

            return true
        }
        image.isTemplate = true
        return image
    }
}
