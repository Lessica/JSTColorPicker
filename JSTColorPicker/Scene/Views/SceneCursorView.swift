//
//  SceneCursorView.swift
//  JSTColorPicker
//
//  Created by Darwin on 3/8/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

final class SceneCursorView: NSView {
    
    weak var backgroundSource: NSView?
    var drawCursorTrackingLinesInScene: Bool = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = false
        
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layerContentsPlacement = .scaleAxesIndependently
    }
    
    override var isFlipped: Bool { true }
    override var wantsDefaultClipping: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }  // disable user interactions
    override func cursorUpdate(with event: NSEvent) { }  // do not perform default behavior
    
}
