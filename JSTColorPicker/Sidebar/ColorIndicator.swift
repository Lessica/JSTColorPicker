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

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let area = NSTrackingArea.init(rect: bounds, options: [.activeInKeyWindow, .cursorUpdate], owner: self, userInfo: nil)
        addTrackingArea(area)
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if let action = action {
            NSApp.sendAction(action, to: self.target, from: self)
        }
    }
    
    override func cursorUpdate(with event: NSEvent) {
        super.cursorUpdate(with: event)
        NSCursor.pointingHand.set()
    }
    
}