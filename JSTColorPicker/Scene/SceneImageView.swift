//
//  SceneImageView.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/14/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa
import Quartz

class SceneImageView: IKImageView {
    /// Use `IKImageView` to enable hardware acceleration
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }  // disable user interactions
    
    override func cursorUpdate(with event: NSEvent) {
        // do not perform default behavior
    }
    
}
