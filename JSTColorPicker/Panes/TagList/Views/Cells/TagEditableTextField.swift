//
//  TagEditableTextField.swift
//  JSTColorPicker
//
//  Created by Darwin on 6/24/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

final class TagEditableTextField: NSTextField {
    
    override func becomeFirstResponder() -> Bool {
        textColor = .labelColor
        return super.becomeFirstResponder()
    }
    
    override func resignFirstResponder() -> Bool {
        return super.resignFirstResponder()
    }
    
}
