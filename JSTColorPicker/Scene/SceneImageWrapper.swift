//
//  SceneImageWrapper.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/15/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class SceneImageWrapper: NSView {
    
    weak var trackingDelegate: SceneTracking?
    weak var trackingToolDelegate: TrackingToolDelegate?
    var trackingTool: TrackingTool {
        didSet {
            if mouseInside() {
                updateCursorDisplay()
            }
        }
    }
    
    fileprivate var allowsMagnify: Bool
    fileprivate var allowsMinify: Bool
    
    fileprivate var trackingArea: NSTrackingArea?
    fileprivate var prevX: Int
    fileprivate var prevY: Int
    
    override init(frame frameRect: NSRect) {
        
        allowsMagnify = true
        allowsMinify = true
        trackingTool = .cursor
        prevX = NSNotFound
        prevY = NSNotFound
        
        super.init(frame: frameRect)
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
        let trackingArea = NSTrackingArea.init(rect: visibleRect, options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        createTrackingArea()
    }
    
    override func mouseEntered(with event: NSEvent) {
        mouseTrackingToolEvent(with: event)
        if mouseTrackingEvent(with: event) {
            
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        mouseTrackingToolEvent(with: event)
        if mouseTrackingEvent(with: event) {
            
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
        if mouseTrackingEvent(with: event) {
            
        }
    }
    
    fileprivate func mouseTrackingEvent(with event: NSEvent) -> Bool {
        let loc = self.convert(event.locationInWindow, from: nil)
        let curX = Int(loc.x)
        let curY = Int(loc.y)
        if (curX != prevX || curY != prevY) && curX >= 0 && curY >= 0 {
            prevX = curX
            prevY = curY
            return trackingDelegate?.mousePositionChanged(self, toPoint: CGPoint(x: curX, y: curY)) ?? false
        }
        return false
    }
    
    fileprivate func mouseTrackingToolEvent(with event: NSEvent) {
        updateCursorDisplay()
    }
    
    fileprivate func updateCursorDisplay() {
        if let delegate = trackingToolDelegate {
            if delegate.trackingToolEnabled(self, tool: trackingTool) {
                trackingTool.cursor.set()
            } else {
                trackingTool.disabledCursor.set()
            }
        }
    }
    
    fileprivate func mouseInside() -> Bool {
        if let locationInWindow = window?.mouseLocationOutsideOfEventStream {
            let loc = convert(locationInWindow, from: nil)
            if NSPointInRect(loc, visibleRect) {
                return true
            }
        }
        return false
    }
    
}
