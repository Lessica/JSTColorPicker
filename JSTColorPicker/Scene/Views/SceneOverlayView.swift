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
    
    public var overlays: [AnnotatorOverlay] {
        return subviews as! [AnnotatorOverlay]
    }
    fileprivate weak var internalFocusedOverlay: AnnotatorOverlay?
    public var isFocused: Bool {
        return sceneTool == .selectionArrow ? internalFocusedOverlay != nil : false
    }
    public var focusedOverlay: AnnotatorOverlay? {
        return sceneTool == .selectionArrow ? internalFocusedOverlay : nil
    }
    public func frontmostOverlay(at point: CGPoint) -> AnnotatorOverlay? {
        return overlays.lazy.compactMap({ $0 as? ColorAnnotatorOverlay }).last(where: { $0.frame.contains(point) })
            ?? overlays.lazy.compactMap({ $0 as? AreaAnnotatorOverlay }).last(where: { $0.frame.contains(point) })
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
    
    public func updateAppearance() {
        internalUpdateFocusAppearance(with: nil)
        internalUpdateCursorAppearance()
    }
    
    fileprivate func internalUpdateFocusAppearance(with event: NSEvent?) {
        guard sceneTool == .selectionArrow else {
            internalResetFocusAppearance()
            return
        }
        
        var mouseLocation: CGPoint
        if let event = event { mouseLocation = event.locationInWindow }
        else if let window = window { mouseLocation = window.mouseLocationOutsideOfEventStream }
        else { return }
        
        let loc = convert(mouseLocation, from: nil)
        if let overlay = self.frontmostOverlay(at: loc) {
            if let focusedOverlay = self.internalFocusedOverlay {
                if overlay != focusedOverlay {
                    focusedOverlay.isFocused = false
                    focusedOverlay.setNeedsDisplay()
                    overlay.isFocused = true
                    overlay.setNeedsDisplay()
                    self.internalFocusedOverlay = overlay
                }
            }
            else {
                overlay.isFocused = true
                overlay.setNeedsDisplay()
                self.internalFocusedOverlay = overlay
            }
        }
        else {
            internalResetFocusAppearance()
        }
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
    
    fileprivate func internalResetFocusAppearance() {
        if let focusedOverlay = self.internalFocusedOverlay {
            focusedOverlay.isFocused = false
            focusedOverlay.setNeedsDisplay()
            self.internalFocusedOverlay = nil
        }
    }
    
    fileprivate func internalResetCursorAppearance() {
        SceneTool.arrowCursor.set()
    }
    
}