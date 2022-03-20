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
    var debugTimer: Timer?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = true
        
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layerContentsPlacement = .scaleAxesIndependently
        compositingFilter = CIFilter(name: "CIColorMonochrome")
        
        debugTimer = Timer(timeInterval: 0.05, repeats: true) { timer in
            self.setNeedsDisplay(self.bounds)
        }
        RunLoop.current.add(debugTimer!, forMode: .default)
    }
    
    override var isFlipped: Bool { true }
    override var wantsDefaultClipping: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }  // disable user interactions
    override func cursorUpdate(with event: NSEvent) { }  // do not perform default behavior
    
    override func draw(_ dirtyRect: NSRect) {
        backgroundSource?.displayIgnoringOpacity(bounds, in: NSGraphicsContext.current!)
    }
    
}
