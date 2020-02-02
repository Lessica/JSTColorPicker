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
    var trackingTool: TrackingTool = .cursor {
        didSet {
            updateCursorDisplay()
        }
    }
    var isBeingManipulated: Bool = false
    
    fileprivate var trackingArea: NSTrackingArea?
    fileprivate var wrapper: SceneImageWrapper {
        return documentView as! SceneImageWrapper
    }
    
    fileprivate var previousCoordinate = PixelCoordinate.invalid
    
    fileprivate func mouseTrackingEvent(with event: NSEvent) {
        let loc = wrapper.convert(event.locationInWindow, from: nil)
        guard wrapper.bounds.contains(loc) else { return }
        let currentCoordinate = PixelCoordinate(loc)
        if currentCoordinate != previousCoordinate {
            previousCoordinate = currentCoordinate
            trackingDelegate?.mousePositionChanged(self, to: currentCoordinate)
        }
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
            if visibleRect.contains(loc) {
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
        mouseTrackingEvent(with: event)
        updateCursorDisplay()
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        mouseTrackingEvent(with: event)
        updateCursorDisplay()
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        mouseTrackingEvent(with: event)
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
        if trackingTool == .cursor {
            // TODO: crop from image
        }
        else if trackingTool == .move {
            let origin = contentView.bounds.origin
            let delta = CGPoint(x: -event.deltaX / magnification, y: -event.deltaY / magnification)
            contentView.setBoundsOrigin(NSPoint(x: origin.x + delta.x, y: origin.y + delta.y))
        }
        else if trackingTool == .magnify {
            // TODO: magnify specified area to fill
        }
        updateCursorDisplay()
    }
    
}
