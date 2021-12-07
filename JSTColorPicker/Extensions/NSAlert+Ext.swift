//
//  NSAlert+Extensions.swift
//  3LED
//
//  Created by Daniel Clelland on 17/04/19.
//  Copyright © 2019 Protonome. All rights reserved.
//

import Cocoa
import PromiseKit


extension NSAlert {

    struct Text {

        var message: String
        var information: String

        init(message: String = "", information: String = "") {
            self.message = message
            self.information = information
        }

    }

    convenience init(style: NSAlert.Style = .informational, text: Text) {
        self.init()
        self.alertStyle = style
        self.messageText = text.message
        self.informativeText = text.information
    }

}


extension NSAlert {

    struct Button {

        var title: String

        init(title: String = "") {
            self.title = title
        }

    }

    convenience init(style: NSAlert.Style = .informational, text: Text, button: Button) {
        self.init(style: style, text: text)
        self.addButton(withTitle: button.title)
        self.addButton(withTitle: NSLocalizedString("Cancel", comment: "NSAlert"))
    }

}


extension NSAlert {

    struct TextField {

        var text: String
        var placeholder: String

        init(text: String = "", placeholder: String = "") {
            self.text = text
            self.placeholder = placeholder
        }

    }

    convenience init(style: NSAlert.Style = .informational, text: Text, textField: TextField, button: Button) {
        self.init(style: style, text: text, button: button)
        self.textField = NSTextField(frame: NSRect(x: 0.0, y: 0.0, width: 240.0, height: 22.0))
        self.textField?.stringValue = textField.text
        self.textField?.placeholderString = textField.placeholder
    }

    var textField: NSTextField? {
        get {
            return accessoryView as? NSTextField
        }
        set {
            accessoryView = newValue
        }
    }

}


extension NSAlert {

    static func action(window: NSWindow? = nil, style: NSAlert.Style = .informational, text: Text, button: Button) -> Promise<Void> {
        let alert = NSAlert(text: text, button: button)
        return alert.promise(for: window)
    }

    static func textField(window: NSWindow? = nil, style: NSAlert.Style = .informational, text: Text, textField: TextField, button: Button) -> Promise<String> {
        let alert = NSAlert(text: text, textField: textField, button: button)
        return alert.promise(for: window).compactMap {
            return alert.textField?.stringValue
        }
    }

}


extension NSAlert {

    func guarantee(for window: NSWindow? = nil) -> Guarantee<NSApplication.ModalResponse> {
        return Guarantee { resolver in
            if let window = window {
                beginSheetModal(for: window) { resp in
                    resolver(resp)
                }
            } else {
                resolver(runModal())
            }
        }
    }

    func promise(for window: NSWindow? = nil) -> Promise<Void> {
        return guarantee(for: window).map { response in
            switch response {
            case .alertFirstButtonReturn:
                return
            default:
                throw PMKError.cancelled
            }
        }
    }

}
