//
//  ColoredView.swift
//  JSTColorPicker
//
//  Created by Darwin on 4/23/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class ColoredView: NSView {
    @IBInspectable var backgroundColor: NSColor = .clear {
        didSet {
            needsDisplay = true
        }
    }
    
    @IBInspectable var borderWidth: CGFloat = 0 {
        didSet {
            needsDisplay = true
        }
    }
    
    @IBInspectable var borderColor: NSColor = .clear {
        didSet {
            needsDisplay = true
        }
    }
    
    @IBInspectable var cornerRadius: CGFloat = 0 {
        didSet {
            needsDisplay = true
        }
    }
    
    @IBInspectable var bypassClicks: Bool = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = true
    }
    
    override var wantsUpdateLayer: Bool { true }
    
    override func updateLayer() {
        super.updateLayer()
        layer?.backgroundColor = backgroundColor.cgColor
        layer?.borderWidth = borderWidth
        layer?.borderColor = borderColor.cgColor
        layer?.cornerRadius = cornerRadius
    }
    
    override func mouseDown(with event: NSEvent) {
        if bypassClicks {
            super.mouseDown(with: event)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if bypassClicks {
            super.mouseUp(with: event)
        }
    }
}
