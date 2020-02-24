//
//  ColorIndicator.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/21/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class ColorIndicator: NSImageView {
    
    var color: NSColor = .clear
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let area = NSTrackingArea.init(rect: bounds, options: [.activeInKeyWindow, .cursorUpdate], owner: self, userInfo: nil)
        addTrackingArea(area)
    }
    
    override func mouseUp(with event: NSEvent) {
        if let action = action {
            NSApp.sendAction(action, to: self.target, from: self)
        }
    }
    
    override func cursorUpdate(with event: NSEvent) {
        NSCursor.pointingHand.set()
    }
    
}
