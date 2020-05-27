//
//  SceneOverlayView.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/29/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class SceneOverlayView: NSView, DragEndpoint {
    
    var state: DragEndpointState = .idle
    
    override func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = false
        
        registerForDraggedTypes([TagListController.dragDropType])
    }
    
    override var isFlipped: Bool { return true }
    override func hitTest(_ point: NSPoint) -> NSView? { return nil }  // disable user interactions
    override func cursorUpdate(with event: NSEvent) { }    // do not perform default behavior
    
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
    fileprivate var sceneTool: SceneTool { return sceneToolDataSource!.sceneTool }
    public weak var sceneStateDataSource: SceneStateDataSource?
    fileprivate var sceneState: SceneState { return sceneStateDataSource!.sceneState }
    public weak var annotatorDataSource: AnnotatorDataSource?
    fileprivate var annotators: [Annotator] { return annotatorDataSource!.annotators }
    
    public var overlays: [AnnotatorOverlay] { return subviews as! [AnnotatorOverlay] }
    fileprivate weak var internalFocusedOverlay: AnnotatorOverlay?
    fileprivate var internalEditableDirection: EditableDirection = .none
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
    public var editableDirection: EditableDirection {
        return focusedOverlay != nil ? internalEditableDirection : .none
    }
    
    public var isMouseInside: Bool {
        if let locationInWindow = window?.mouseLocationOutsideOfEventStream {
            let loc = convert(locationInWindow, from: nil)
            if bounds.contains(loc) {
                return true
            }
        }
        return false
    }
    
    override func mouseEntered(with event: NSEvent) {
        updateAppearance(with: event.locationInWindow)
    }
    
    override func mouseMoved(with event: NSEvent) {
        updateAppearance(with: event.locationInWindow)
    }
    
    override func mouseExited(with event: NSEvent) {
        resetAppearance()
    }
    
    override func mouseDown(with event: NSEvent) {
        updateAppearance(with: event.locationInWindow)
    }
    
    override func rightMouseDown(with event: NSEvent) {
        updateAppearance(with: event.locationInWindow)
    }
    
    override func mouseUp(with event: NSEvent) {
        updateAppearance(with: event.locationInWindow)
    }
    
    override func rightMouseUp(with event: NSEvent) {
        updateAppearance(with: event.locationInWindow)
    }
    
    override func mouseDragged(with event: NSEvent) {
        updateAppearance(with: event.locationInWindow)
    }
    
    override func rightMouseDragged(with event: NSEvent) {
        updateAppearance(with: event.locationInWindow)
    }
    
    override func scrollWheel(with event: NSEvent) {
        updateAppearance(with: event.locationInWindow)
    }
    
    override func magnify(with event: NSEvent) {
        updateAppearance(with: event.locationInWindow)
    }
    
    override func smartMagnify(with event: NSEvent) {
        updateAppearance(with: event.locationInWindow)
    }
    
    public func updateAppearance() {
        updateAppearance(with: nil)
    }
    
    fileprivate func updateAppearance(with locInWindow: CGPoint?) {
        guard isMouseInside else { return }
        internalUpdateFocusAppearance(with: locInWindow)
        internalUpdateCursorAppearance(with: locInWindow)
    }
    
    fileprivate func resetAppearance() {
        internalResetFocusAppearance()
        internalResetCursorAppearance()
    }
    
    fileprivate func internalUpdateFocusAppearance(with locInWindow: CGPoint?) {
        guard sceneTool == .selectionArrow else {
            internalResetFocusAppearance()
            return
        }
        
        guard let mouseLocation: CGPoint = locInWindow ?? window?.mouseLocationOutsideOfEventStream else { return }
        
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
    
    fileprivate func internalUpdateCursorAppearance(with locInWindow: CGPoint?) {
        guard let sceneToolDataSource = sceneToolDataSource else { return }
        if sceneToolDataSource.sceneToolEnabled(self) {
            if sceneState.isManipulating {
                if sceneState.type != .forbidden {
                    sceneTool.manipulatingCursor.set()
                }
                else {
                    sceneTool.disabledCursor.set()
                }
            }
            else if let focusedOverlay = focusedOverlay {
                if let mouseLocation = locInWindow ?? window?.mouseLocationOutsideOfEventStream {
                    let locInOverlay = focusedOverlay.convert(mouseLocation, from: nil)
                    let direction = focusedOverlay.direction(at: locInOverlay)
                    sceneTool.focusingCursorForEditableDirection(direction).set()
                }
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
    
    
    // MARK: - Drag/Drop
    
    fileprivate func isAcceptableDraggingTarget(_ target: AnnotatorOverlay?) -> Bool {
        guard target != nil else { return false }
        if let _ = target as? AreaAnnotatorOverlay {
            return true
        }
        return false
    }
    
    fileprivate func updateDraggingAppearance(with locInWindow: CGPoint?) {
        guard isMouseInside else { return }
        internalUpdateFocusAppearance(with: locInWindow)
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard case .idle = state else { return [] }
        guard (sender.draggingSource as? DragConnectionController)?.sourceEndpoint != nil else { return [] }
        updateDraggingAppearance(with: sender.draggingLocation)
        if isAcceptableDraggingTarget(internalFocusedOverlay) {
            state = .target
            return sender.draggingSourceOperationMask
        } else {
            state = .source
        }
        return []
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard state != .idle else { return [] }
        guard (sender.draggingSource as? DragConnectionController)?.sourceEndpoint != nil else { return [] }
        updateDraggingAppearance(with: sender.draggingLocation)
        if isAcceptableDraggingTarget(internalFocusedOverlay) {
            state = .target
            return sender.draggingSourceOperationMask
        } else {
            state = .source
        }
        return []
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        guard case .target = state else { return }
        resetAppearance()
        state = .idle
    }
    
    override func draggingEnded(_ sender: NSDraggingInfo) {
        guard case .target = state else { return }
        resetAppearance()
        state = .idle
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let controller = sender.draggingSource as? DragConnectionController else { return false }
        controller.connect(to: self)
        
        // TODO: get focused overlay and its content item, then do item modifications
        
        return true
    }
    
}
