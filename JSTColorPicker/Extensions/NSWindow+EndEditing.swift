//
//  NSWindow+EndEditing.swift
//  JSTColorPicker
//
//  Created by Darwin on 2022/4/19.
//  Copyright © 2022 JST. All rights reserved.
//

import Cocoa

extension NSWindow {
    
    /// end current editing and restore the current responder afterwards
    @discardableResult
    func endEditing() -> Bool {
        
        let responder: NSResponder?
        if let editor = self.firstResponder as? NSTextView, editor.isFieldEditor {
            // -> Regarding field editors, the real first responder is its delegate.
            responder = editor.delegate as? NSResponder
        } else {
            responder = self.firstResponder
        }
        
        let sucsess = self.makeFirstResponder(nil)
        
        // restore current responder
        if sucsess, let responder = responder {
            self.makeFirstResponder(responder)
        }
        
        return sucsess
    }
    
}

extension NSViewController {
    
    /// end current editing and restore the current responder afterwards
    @objc @discardableResult
    func endEditing() -> Bool {
        
        guard self.isViewLoaded else { return true }
        
        return self.view.window?.endEditing() ?? false
    }
    
}
