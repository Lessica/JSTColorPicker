//
//  SceneTagView.swift
//  JSTColorPicker
//
//  Created by Darwin on 6/2/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class SceneTagView: NSView {

    override func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = false
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }  // disable user interactions
    
    override func cursorUpdate(with event: NSEvent) {
        // do not perform default behavior
    }
    
}
