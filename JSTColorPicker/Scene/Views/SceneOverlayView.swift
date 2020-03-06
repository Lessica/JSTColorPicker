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
    override var isFlipped: Bool {
        return true
    }
    
    fileprivate var trackingArea: NSTrackingArea?
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
    fileprivate weak var focusedOverlay: Overlay?
    fileprivate var isFocused: Bool {
        return sceneTool == .selectionArrow ? focusedOverlay != nil : false
    }
    fileprivate func frontmostOverlay(at point: CGPoint) -> Overlay? {
        return overlays.last(where: { $0.frame.contains(point) })
    }
    
    override func cursorUpdate(with event: NSEvent) {
        // do not perform default behavior
    }
    
    override func mouseEntered(with event: NSEvent) {
        internalUpdateFocusAppearance(with: event)
        internalUpdateCursorAppearance()
    }
    
    override func mouseMoved(with event: NSEvent) {
        internalUpdateFocusAppearance(with: event)
        internalUpdateCursorAppearance()
    }
    
    override func mouseExited(with event: NSEvent) {
        internalResetFocusAppearance()
        internalResetCursorAppearance()
    }
    
    override func mouseDown(with event: NSEvent) {
        internalUpdateFocusAppearance(with: event)
        internalUpdateCursorAppearance()
    }
    
    override func rightMouseDown(with event: NSEvent) {
        internalUpdateFocusAppearance(with: event)
        internalUpdateCursorAppearance()
    }
    
    override func mouseUp(with event: NSEvent) {
        internalUpdateFocusAppearance(with: event)
        internalUpdateCursorAppearance()
    }
    
    override func rightMouseUp(with event: NSEvent) {
        internalUpdateFocusAppearance(with: event)
        internalUpdateCursorAppearance()
    }
    
    override func mouseDragged(with event: NSEvent) {
        internalUpdateFocusAppearance(with: event)
        internalUpdateCursorAppearance()
    }
    
    override func rightMouseDragged(with event: NSEvent) {
        internalUpdateFocusAppearance(with: event)
        internalUpdateCursorAppearance()
    }
    
    override func scrollWheel(with event: NSEvent) {
        internalUpdateFocusAppearance(with: event)
        internalUpdateCursorAppearance()
    }
    
    override func magnify(with event: NSEvent) {
        internalUpdateFocusAppearance(with: event)
        internalUpdateCursorAppearance()
    }
    
    override func smartMagnify(with event: NSEvent) {
        internalUpdateFocusAppearance(with: event)
        internalUpdateCursorAppearance()
    }
    
    public func updateCursorAppearance() {
        internalUpdateCursorAppearance()
    }
    
    fileprivate func internalUpdateCursorAppearance() {
        guard let sceneToolDataSource = sceneToolDataSource else { return }
        if sceneToolDataSource.sceneToolEnabled(self, tool: sceneTool) {
            if sceneState.isManipulating {
                if sceneState.type != .forbidden {
                    sceneTool.manipulatingCursor.set()
                }
                else {
                    sceneTool.disabledCursor.set()
                }
            }
            else if isFocused {
                sceneTool.focusingCursor.set()
            }
            else {
                sceneTool.normalCursor.set()
            }
        } else {
            sceneTool.disabledCursor.set()
        }
    }
    
    fileprivate func internalResetCursorAppearance() {
        SceneTool.arrowCursor.set()
    }
    
    fileprivate func internalUpdateFocusAppearance(with event: NSEvent?) {
        guard sceneTool == .selectionArrow else { return }
        guard let event = event else { return }
        let loc = convert(event.locationInWindow, from: nil)
        if let overlay = self.frontmostOverlay(at: loc) {
            if let focusedOverlay = self.focusedOverlay {
                if overlay != focusedOverlay {
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
        else if let focusedOverlay = self.focusedOverlay {
            focusedOverlay.isFocused = false
            focusedOverlay.setNeedsDisplay()
            self.focusedOverlay = nil
        }
    }
    
    fileprivate func internalResetFocusAppearance() {
        if let focusedOverlay = self.focusedOverlay {
            focusedOverlay.isFocused = false
            focusedOverlay.setNeedsDisplay()
            self.focusedOverlay = nil
        }
    }
    
}
