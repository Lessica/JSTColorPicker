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
        
        registerForDraggedTypes([TagListController.attachPasteboardType])
    }
    
    override var isFlipped: Bool { true }
    override var wantsDefaultClipping: Bool { false }
    
    override func hitTest(_ point: NSPoint) -> NSView? { nil }  // disable user interactions
    override func cursorUpdate(with event: NSEvent) { }  // do not perform default behavior
    
    private var trackingArea: NSTrackingArea?
    private func createTrackingArea() {
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
    
    public weak var contentDelegate: ContentDelegate!
    public weak var sceneToolSource: SceneToolSource!
    private var sceneTool: SceneTool { sceneToolSource.sceneTool }
    public weak var sceneStateSource: SceneStateSource!
    private var sceneState: SceneState { sceneStateSource.sceneState }
    public weak var sceneTagsEffectViewSource: SceneEffectViewSource!
    private var sceneTagsEffectView: SceneEffectView { sceneTagsEffectViewSource.sceneEffectView }
    public weak var annotatorSource: AnnotatorSource!
    private var annotators: [Annotator] { annotatorSource.annotators }
    private func contentItem(of overlay: AnnotatorOverlay) -> ContentItem? {
        return annotators.first(where: { $0.overlay == overlay })?.contentItem
    }
    
    public var overlays: [AnnotatorOverlay] { subviews as! [AnnotatorOverlay] }
    private weak var internalFocusedOverlay: AnnotatorOverlay?
    
    public var editableDirection: EditableDirection { focusedOverlay != nil ? internalEditableDirection : .none }
    private var internalEditableDirection: EditableDirection = .none
    
    public var isFocused: Bool { sceneTool == .selectionArrow ? internalFocusedOverlay != nil : false }
    public var focusedOverlay: AnnotatorOverlay? { sceneTool == .selectionArrow ? internalFocusedOverlay : nil }
    
    public func frontmostOverlay(at point: CGPoint) -> AnnotatorOverlay? {
        overlays.lazy.compactMap({ $0 as? ColorAnnotatorOverlay }).last(where: { $0.frame.contains(point) })
            ?? overlays.lazy.compactMap({ $0 as? AreaAnnotatorOverlay }).last(where: { $0.frame.contains(point) })
    }
    public func overlays(at point: CGPoint, byReordering reorder: Bool) -> [AnnotatorOverlay] {
        // FIXME: reorder
        return overlays.filter({ $0.frame.contains(point) })
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
    
    private func updateAppearance(with locInWindow: CGPoint?) {
        guard isMouseInside else { return }
        internalUpdateFocusAppearance(with: locInWindow)
        internalUpdateCursorAppearance(with: locInWindow)
    }
    
    private func resetAppearance() {
        internalResetFocusAppearance()
        internalResetCursorAppearance()
    }
    
    private func internalUpdateFocusAppearance(with locInWindow: CGPoint?) {
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
                    focusedOverlay.setNeedsDisplay(visibleOnly: false)
                    overlay.isFocused = true
                    overlay.setNeedsDisplay(visibleOnly: false)
                    self.internalFocusedOverlay = overlay
                }
            }
            else {
                overlay.isFocused = true
                overlay.setNeedsDisplay(visibleOnly: false)
                self.internalFocusedOverlay = overlay
            }
        }
        else {
            internalResetFocusAppearance()
        }
    }
    
    private func internalUpdateCursorAppearance(with locInWindow: CGPoint?) {
        if sceneToolSource.sceneToolEnabled {
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
    
    private func internalResetFocusAppearance() {
        if let focusedOverlay = self.internalFocusedOverlay {
            focusedOverlay.isFocused = false
            focusedOverlay.setNeedsDisplay(visibleOnly: false)
            self.internalFocusedOverlay = nil
        }
    }
    
    private func internalResetCursorAppearance() {
        SceneTool.arrowCursor.set()
    }
    
    
    // MARK: - Drag/Drop
    
    private func isAcceptableDraggingTarget(_ draggingInfo: NSDraggingInfo, target: AnnotatorOverlay?) -> Bool {
        guard target != nil else { return false }
        return true
    }
    
    private func updateDraggingAppearance(with locInWindow: CGPoint?) {
        guard isMouseInside else { return }
        internalUpdateFocusAppearance(with: locInWindow)
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard case .idle = state else { return [] }
        guard (sender.draggingSource as? DragConnectionController)?.sourceEndpoint != nil else { return [] }
        updateDraggingAppearance(with: sender.draggingLocation)
        if isAcceptableDraggingTarget(sender, target: internalFocusedOverlay) {
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
        if isAcceptableDraggingTarget(sender, target: internalFocusedOverlay) {
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
        guard let focusedOverlay = internalFocusedOverlay,
            isAcceptableDraggingTarget(sender, target: focusedOverlay) else { return false }
        guard let origItem = contentItem(of: focusedOverlay) else { return false }
        guard let replItem = origItem.copy() as? ContentItem else { return false }
            
        guard let controller = sender.draggingSource as? DragConnectionController else { return false }
        controller.connect(to: self)
        
        sender.enumerateDraggingItems(options: [], for: self, classes: [NSPasteboardItem.self], searchOptions: [:]) { (dragItem, _, _) in
            if let obj = (dragItem.item as! NSPasteboardItem).propertyList(forType: TagListController.attachPasteboardType) as? [String] {
                obj.forEach({ replItem.tags.append($0) })
            }
        }
        
        if let _ = try? contentDelegate.updateContentItem(replItem) {
            return true
        }
        
        return false
    }
    
}
