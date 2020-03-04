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
    
    public weak var sceneToolDataSource: SceneToolDataSource?
    fileprivate var sceneTool: SceneTool {
        return sceneToolDataSource!.sceneTool
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
        SceneTool.arrowCursor.set()
    }
    
    override func mouseDown(with event: NSEvent) {
        updateCursorAppearance()
    }
    
    override func rightMouseDown(with event: NSEvent) {
        updateCursorAppearance()
    }
    
    override func mouseUp(with event: NSEvent) {
        updateCursorAppearance()
    }
    
    override func rightMouseUp(with event: NSEvent) {
        updateCursorAppearance()
    }
    
    override func mouseDragged(with event: NSEvent) {
        updateCursorAppearance()
    }
    
    override func rightMouseDragged(with event: NSEvent) {
        updateCursorAppearance()
    }
    
    fileprivate func updateCursorAppearance() {
        guard let sceneToolDataSource = sceneToolDataSource else { return }
        if sceneToolDataSource.sceneToolEnabled(self, tool: sceneTool) {
            if sceneState.isManipulating {
                if sceneState.type != .forbidden {
                    sceneTool.highlightCursor.set()
                }
                else {
                    sceneTool.disabledCursor.set()
                }
            }
            else {
                sceneTool.currentCursor.set()
            }
        } else {
            sceneTool.disabledCursor.set()
        }
    }
    
}
