//
//  SceneEffectView.swift
//  JSTColorPicker
//
//  Created by Darwin on 3/8/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol SceneEffectViewDataSource: class {
    var sceneEffectView: SceneEffectView { get }
}

class SceneEffectView: NSView {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = false
    }
    
    override var isFlipped: Bool { true }
    override var wantsDefaultClipping: Bool { false }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }  // disable user interactions
    
    override func cursorUpdate(with event: NSEvent) {
        // do not perform default behavior
    }
    
}
