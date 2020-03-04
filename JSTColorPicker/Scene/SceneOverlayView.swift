//
//  SceneOverlayView.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/29/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class SceneOverlayView: NSView {
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
    
    fileprivate var trackingArea: NSTrackingArea?
    
    public weak var trackingToolDataSource: TrackingToolDataSource?
    fileprivate var trackingTool: TrackingTool {
        return trackingToolDataSource!.trackingTool
    }
    
    public weak var sceneStateDataSource: SceneStateDataSource?
    fileprivate var sceneState: SceneState {
        get {
            return sceneStateDataSource!.sceneState
        }
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    fileprivate func createTrackingArea() {
        let trackingArea = NSTrackingArea.init(rect: bounds, options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow], owner: self, userInfo: nil)
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
        updateCursorAppearance()
    }
    
    override func mouseMoved(with event: NSEvent) {
        updateCursorAppearance()
    }
    
    override func mouseExited(with event: NSEvent) {
        TrackingTool.arrowCursor.set()
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        updateCursorAppearance()
    }
    
    override func rightMouseDown(with event: NSEvent) {
        super.rightMouseDown(with: event)
        updateCursorAppearance()
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        updateCursorAppearance()
    }
    
    override func rightMouseUp(with event: NSEvent) {
        super.rightMouseUp(with: event)
        updateCursorAppearance()
    }
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        updateCursorAppearance()
    }
    
    override func rightMouseDragged(with event: NSEvent) {
        super.rightMouseDragged(with: event)
        updateCursorAppearance()
    }
    
    fileprivate func updateCursorAppearance() {
        guard let trackingToolDataSource = trackingToolDataSource else { return }
        if trackingToolDataSource.trackingToolEnabled(self, tool: trackingTool) {
            if sceneState.isManipulating {
                if sceneState.type != .forbidden {
                    trackingTool.highlightCursor.set()
                }
                else {
                    trackingTool.disabledCursor.set()
                }
            }
            else {
                trackingTool.currentCursor.set()
            }
        } else {
            trackingTool.disabledCursor.set()
        }
    }
    
}
