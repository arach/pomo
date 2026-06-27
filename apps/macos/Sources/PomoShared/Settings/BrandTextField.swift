import SwiftUI
import AppKit

/// A plain text field whose **selection** stays high-contrast even when the host
/// window isn't key. (macOS otherwise draws a washed-out inactive selection — so
/// a highlighted URL becomes hard to read in the HUD/Settings panels.)
struct BrandTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var textColor: Color
    var selectionColor: Color
    var fontSize: CGFloat = 12

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> SelectionTextField {
        let field = SelectionTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        field.textColor = NSColor(textColor)
        field.placeholderString = placeholder
        field.lineBreakMode = .byTruncatingMiddle
        field.cell?.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.delegate = context.coordinator
        field.selectionBackground = NSColor(selectionColor)
        field.selectionForeground = .black
        return field
    }

    func updateNSView(_ field: SelectionTextField, context: Context) {
        if field.stringValue != text { field.stringValue = text }
        field.textColor = NSColor(textColor)
        field.selectionBackground = NSColor(selectionColor)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func controlTextDidChange(_ note: Notification) {
            guard let field = note.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}

/// NSTextField that paints its selection with an explicit colour (via the shared
/// field editor) so it reads the same whether or not the window is key.
final class SelectionTextField: NSTextField {
    var selectionBackground: NSColor = .selectedTextBackgroundColor
    var selectionForeground: NSColor = .black

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became, let editor = currentEditor() as? NSTextView {
            editor.selectedTextAttributes = [
                .backgroundColor: selectionBackground,
                .foregroundColor: selectionForeground,
            ]
            editor.insertionPointColor = selectionBackground
        }
        return became
    }
}
