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
        return sceneStateDataSource!.sceneState
    }
    
    public weak var annotatorDataSource: AnnotatorDataSource?
    fileprivate var annotators: [Annotator] {
        return annotatorDataSource!.annotators
    }
    
    fileprivate var overlays: [Overlay] {
        return subviews as! [Overlay]
    }
    fileprivate var focusedOverlay: Overlay?
    fileprivate func frontmostOverlay(at point: CGPoint) -> Overlay? {
        return overlays.reversed().first(where: { $0.frame.contains(point) })
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
        internalUpdateCursorAppearance()
        internalUpdateFocusAppearance(with: event)
    }
    
    override func mouseMoved(with event: NSEvent) {
        internalUpdateCursorAppearance()
        internalUpdateFocusAppearance(with: event)
    }
    
    override func mouseExited(with event: NSEvent) {
        internalResetCursorAppearance()
        internalResetFocusAppearance()
    }
    
    override func mouseDown(with event: NSEvent) {
        internalUpdateCursorAppearance()
        internalUpdateFocusAppearance(with: event)
    }
    
    override func rightMouseDown(with event: NSEvent) {
        internalUpdateCursorAppearance()
        internalUpdateFocusAppearance(with: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        internalUpdateCursorAppearance()
        internalUpdateFocusAppearance(with: event)
    }
    
    override func rightMouseUp(with event: NSEvent) {
        internalUpdateCursorAppearance()
        internalUpdateFocusAppearance(with: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        internalUpdateCursorAppearance()
        internalUpdateFocusAppearance(with: event)
    }
    
    override func rightMouseDragged(with event: NSEvent) {
        internalUpdateCursorAppearance()
        internalUpdateFocusAppearance(with: event)
    }
    
    public func updateCursorAppearance() {
        internalUpdateCursorAppearance()
    }
    
    fileprivate func internalUpdateCursorAppearance() {
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
    
    fileprivate func internalResetCursorAppearance() {
        SceneTool.arrowCursor.set()
    }
    
    fileprivate func internalUpdateFocusAppearance(with event: NSEvent?) {
        guard let event = event else { return }
        let loc = convert(event.locationInWindow, from: nil)
        if let overlay = frontmostOverlay(at: loc) {
            if let focusedOverlay = focusedOverlay {
                if overlay == focusedOverlay {
                    
                }
                else {
                    focusedOverlay.isFocused = false
                    focusedOverlay.setNeedsDisplay()
                    overlay.isFocused = true
                    overlay.setNeedsDisplay()
                    self.focusedOverlay = overlay
                }
            }
            else {
                overlay.isFocused = true
                overlay.setNeedsDisplay()
                self.focusedOverlay = overlay
            }
        }
        else if let focusedOverlay = focusedOverlay {
            focusedOverlay.isFocused = false
            focusedOverlay.setNeedsDisplay()
            self.focusedOverlay = nil
        }
    }
    
    fileprivate func internalResetFocusAppearance() {
        if let focusedOverlay = focusedOverlay {
            focusedOverlay.isFocused = false
            focusedOverlay.setNeedsDisplay()
            self.focusedOverlay = nil
        }
    }
    
}
