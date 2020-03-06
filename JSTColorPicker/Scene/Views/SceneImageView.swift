//
//  SceneImageView.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/14/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class SceneImageView: NSView {
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }  // disable user interactions
    
    override func cursorUpdate(with event: NSEvent) {
        // do not perform default behavior
    }
    
    override var acceptsFirstResponder: Bool {
        return false
    }
    
    override var isOpaque: Bool {
        return true
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.isOpaque = true
        layer?.magnificationFilter = .nearest
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setImage(_ image: CGImage) {
        layer?.contents = image
    }
    
}