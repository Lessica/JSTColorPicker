//
//  SceneScrollView.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/13/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class SceneScrollView: NSScrollView {
    
    weak var trackingDelegate: SceneTracking?
    weak var trackingToolDelegate: TrackingToolDelegate?
    fileprivate var trackingArea: NSTrackingArea?
    var trackingTool: TrackingTool {
        didSet {
            updateCursorDisplay()
        }
    }
    fileprivate var wrapper: SceneImageWrapper {
        return documentView as! SceneImageWrapper
    }
    
    fileprivate var allowsMagnify: Bool
    fileprivate var allowsMinify: Bool
    fileprivate var isBeingManipulated: Bool
    
    fileprivate var prevX: Int
    fileprivate var prevY: Int
    
    required init?(coder: NSCoder) {
        allowsMagnify = true
        allowsMinify = true
        isBeingManipulated = false
        trackingTool = .cursor
        prevX = NSNotFound
        prevY = NSNotFound
        
        super.init(coder: coder)
    }
    
    fileprivate func mouseTrackingEvent(with event: NSEvent) -> Bool {
        let loc = wrapper.convert(event.locationInWindow, from: nil)
        let curX = Int(loc.x)
        let curY = Int(loc.y)
        if (curX != prevX || curY != prevY) && curX >= 0 && curY >= 0 {
            prevX = curX
            prevY = curY
            return trackingDelegate?.mousePositionChanged(self, toPoint: CGPoint(x: curX, y: curY)) ?? false
        }
        return false
    }
    
    fileprivate func updateCursorDisplay() {
        guard let delegate = trackingToolDelegate else { return }
        if !mouseInside() { return }
        if delegate.trackingToolEnabled(self, tool: trackingTool) {
            if !isBeingManipulated {
                trackingTool.currentCursor.set()
            } else {
                trackingTool.highlightCursor.set()
            }
        } else {
            trackingTool.disabledCursor.set()
        }
    }
    
    fileprivate func resetCursorDisplay() {
        NSCursor.arrow.set()
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
    
    fileprivate func createTrackingArea() {
        let trackingArea = NSTrackingArea.init(rect: visibleRect, options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }
    
    override func updateTrackingAreas() {
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        createTrackingArea()
        super.updateTrackingAreas()
    }
    
    override func cursorUpdate(with event: NSEvent) {
        // do not perform default behavior
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        _ = mouseTrackingEvent(with: event)
        updateCursorDisplay()
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        _ = mouseTrackingEvent(with: event)
        updateCursorDisplay()
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        _ = mouseTrackingEvent(with: event)
        resetCursorDisplay()
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        isBeingManipulated = true
        updateCursorDisplay()
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        isBeingManipulated = false
        updateCursorDisplay()
    }
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        if trackingTool == .move {
            let origin = contentView.bounds.origin
            let delta = CGPoint(x: -event.deltaX / magnification, y: -event.deltaY / magnification)
            contentView.setBoundsOrigin(NSPoint(x: origin.x + delta.x, y: origin.y + delta.y))
        }
        updateCursorDisplay()
    }
    
}
