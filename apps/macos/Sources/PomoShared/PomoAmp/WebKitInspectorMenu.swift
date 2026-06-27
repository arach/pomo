import AppKit
import WebKit

enum WebKitInspectorMenu {
    private static let itemIdentifier = NSUserInterfaceItemIdentifier("PomoAmpOpenWebInspector")
    private static let target = WebKitInspectorMenuTarget()

    static func enableInspection(on webView: WKWebView) {
        #if DEBUG
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }
        #endif
    }

    static func addOpenInspectorItem(to menu: NSMenu, webView: WKWebView) {
        #if DEBUG
        enableInspection(on: webView)
        guard !menu.items.contains(where: { $0.identifier == itemIdentifier }) else { return }
        if menu.items.last?.isSeparatorItem == false {
            menu.addItem(.separator())
        }

        let item = NSMenuItem(title: "Open Web Inspector", action: #selector(WebKitInspectorMenuTarget.open(_:)), keyEquivalent: "")
        item.identifier = itemIdentifier
        item.target = target
        item.representedObject = webView
        item.image = NSImage(systemSymbolName: "curlybraces.square", accessibilityDescription: nil)
        menu.addItem(item)
        #endif
    }

    @discardableResult
    static func openInspector(for webView: WKWebView) -> Bool {
        #if DEBUG
        enableInspection(on: webView)
        webView.window?.makeKeyAndOrderFront(nil)

        let inspectorSelector = Selector(("_inspector"))
        guard webView.responds(to: inspectorSelector),
              let inspector = webView.perform(inspectorSelector)?.takeUnretainedValue()
        else { return false }

        let showSelector = Selector(("show"))
        guard (inspector as AnyObject).responds(to: showSelector) else { return false }
        _ = (inspector as AnyObject).perform(showSelector)
        return true
        #else
        return false
        #endif
    }
}

private final class WebKitInspectorMenuTarget: NSObject {
    @objc func open(_ sender: NSMenuItem) {
        guard let webView = sender.representedObject as? WKWebView else { return }
        WebKitInspectorMenu.openInspector(for: webView)
    }
}
