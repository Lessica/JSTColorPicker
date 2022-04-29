//
//  ClickToSelectAllField.swift
//  JSTColorPicker
//
//  Created by Darwin on 4/28/22.
//  Copyright © 2022 JST. All rights reserved.
//

import Cocoa

final class ClickToSelectAllField: NSTextField {
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if let textEditor = currentEditor() {
            textEditor.selectAll(self)
        }
    }
}
