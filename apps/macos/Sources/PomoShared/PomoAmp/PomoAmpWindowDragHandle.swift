import AppKit
import SwiftUI

struct PomoAmpWindowDragHandle: NSViewRepresentable {
    var onMiddleClick: (() -> Void)?

    func makeNSView(context: Context) -> NSView {
        let view = DragView()
        view.onMiddleClick = onMiddleClick
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? DragView)?.onMiddleClick = onMiddleClick
    }

    final class DragView: NSView {
        var onMiddleClick: (() -> Void)?

        override var mouseDownCanMoveWindow: Bool { true }

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor
        }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }

        override func otherMouseDown(with event: NSEvent) {
            guard event.buttonNumber == 2 else {
                super.otherMouseDown(with: event)
                return
            }
            onMiddleClick?()
        }
    }
}
