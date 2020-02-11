//
//  SceneScrollOverlayView.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/29/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class SceneScrollOverlayView: NSView {
    
    fileprivate var trackingArea: NSTrackingArea?
    
    override var isFlipped: Bool {
        return true
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }  // disable user interactions
    
    override func cursorUpdate(with event: NSEvent) {
        // do not perform default behavior
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
        let trackingArea = NSTrackingArea.init(rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
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
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
    }
    
    override func rightMouseDown(with event: NSEvent) {
        super.rightMouseDown(with: event)
    }
    
    override func rightMouseUp(with event: NSEvent) {
        super.rightMouseUp(with: event)
    }
    
    override func rightMouseDragged(with event: NSEvent) {
        super.rightMouseDragged(with: event)
    }
    
    override func otherMouseDown(with event: NSEvent) {
        super.otherMouseDown(with: event)
    }
    
    override func otherMouseUp(with event: NSEvent) {
        super.otherMouseUp(with: event)
    }
    
    override func otherMouseDragged(with event: NSEvent) {
        super.otherMouseDragged(with: event)
    }
    
    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
    }
    
    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
    }
    
    override func keyUp(with event: NSEvent) {
        super.keyUp(with: event)
    }
    
    override func flagsChanged(with event: NSEvent) {
        super.flagsChanged(with: event)
    }
    
}
