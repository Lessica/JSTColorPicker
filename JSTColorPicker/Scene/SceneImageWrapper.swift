//
//  SceneImageWrapper.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/15/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol SceneTracking {
    func mousePositionChanged(_ wrapper: SceneImageWrapper, toPoint point: CGPoint)
}

class SceneImageWrapper: NSView {
    
    var trackingDelegate: SceneTracking?
    fileprivate var trackingArea: NSTrackingArea?
    fileprivate var prevX: Int
    fileprivate var prevY: Int
    
    override init(frame frameRect: NSRect) {
        prevX = NSNotFound
        prevY = NSNotFound
        super.init(frame: frameRect)
        createTrackingArea()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var isFlipped: Bool {
        get {
            return true
        }
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }  // disable user interactions
    
    fileprivate func createTrackingArea() {
        let trackingArea = NSTrackingArea.init(rect: bounds, options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }
    
    override func mouseEntered(with event: NSEvent) {
        debugPrint("mouseEntered")
        mouseEvent(with: event)
    }
    
    override func mouseMoved(with event: NSEvent) {
        mouseEvent(with: event)
    }
    
    override func mouseExited(with event: NSEvent) {
        debugPrint("mouseExited")
        mouseEvent(with: event)
    }
    
    fileprivate func mouseEvent(with event: NSEvent) {
        let loc = self.convert(event.locationInWindow, from: nil)
        let curX = Int(loc.x)
        let curY = Int(loc.y)
        if (curX != prevX || curY != prevY) && curX >= 0 && curY >= 0 {
            prevX = curX
            prevY = curY
            trackingDelegate?.mousePositionChanged(self, toPoint: CGPoint(x: curX, y: curY))
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        
    }
    
    override func mouseUp(with event: NSEvent) {
        
    }
    
}
