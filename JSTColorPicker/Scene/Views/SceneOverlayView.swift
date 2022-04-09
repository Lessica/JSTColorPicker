//
//  SceneOverlayView.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/29/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

final class SceneOverlayView: NSView {
    
    var dragEndpointState: DragEndpointState = .idle
    
    var maximumTagPerItem: Int = 0
    var maximumTagPerItemEnabled: Bool = false
    var replaceSingleTagWhileDrop: Bool = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = false
        
        registerForDraggedTypes([TagListController.attachPasteboardType])
    }
    
    override var isFlipped             : Bool { true  }
    override var wantsDefaultClipping  : Bool { false }
    
    override func hitTest(_ point: NSPoint) -> NSView? { nil }  // disable user interactions
    override func cursorUpdate(with event: NSEvent) { }  // do not perform default behavior
    
    private var trackingArea: NSTrackingArea?
    private func createTrackingArea() {
        let trackingArea = NSTrackingArea.init(
            rect: bounds,
            options: [
                .mouseEnteredAndExited, .mouseMoved,
                .activeInKeyWindow, .activeInActiveApp,
            ],
            owner: self,
            userInfo: nil
        )
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
    
    weak var contentDelegate                   : ContentActionResponder!
    weak var sceneToolSource                   : SceneToolSource!
    private var sceneTool                      : SceneTool               { sceneToolSource.sceneTool }
    weak var sceneStateSource                  : SceneStateSource!
    private var sceneState                     : SceneState              { sceneStateSource.sceneState }
    weak var sceneTagsEffectViewSource         : SceneEffectViewSource!
    private var sceneTagsEffectView            : SceneEffectView         { sceneTagsEffectViewSource.sourceSceneEffectView }
    weak var annotatorSource                   : AnnotatorSource!
    private var annotators                     : [Annotator]             { annotatorSource.annotators }
    private func contentItem(of overlay: AnnotatorOverlay) -> ContentItem? {
        return annotators.first(where: { $0.overlay == overlay })?.contentItem
    }
    
    var overlays: [AnnotatorOverlay] { subviews as! [AnnotatorOverlay] }
    private weak var internalFocusedOverlay: AnnotatorOverlay?
    
    var editableDirection: EditableOverlay.Direction { focusedOverlay != nil ? internalEditableDirection : .none }
    private var internalEditableDirection: EditableOverlay.Direction = .none
    
    internal var hasFocusingCursor: Bool {
        sceneTool.hasFocusingCursorWithoutDragging || dragEndpointState != .idle
    }
    internal var isFocused: Bool {
        hasFocusingCursor ? internalFocusedOverlay != nil : false
    }
    internal var focusedOverlay: AnnotatorOverlay? {
        hasFocusingCursor ? internalFocusedOverlay : nil
    }

    var hasSelectedOverlay: Bool { overlays.firstIndex(where: { $0.isSelected }) != nil }
    var selectedOverlays: [AnnotatorOverlay] { overlays.filter({ $0.isSelected }) }
    
    func frontmostOverlay(at point: CGPoint) -> AnnotatorOverlay? {
        overlays.lazy.compactMap({ $0 as? ColorAnnotatorOverlay }).last(where: { $0.frame.contains(point) })
            ?? overlays.lazy.compactMap({ $0 as? AreaAnnotatorOverlay }).last(where: { $0.frame.contains(point) })
    }

    func overlays(at point: CGPoint, bySizeReordering reorder: Bool = false) -> [AnnotatorOverlay] {
        if !reorder {
            return overlays
                .filter({ $0.frame.contains(point) })
        } else {
            return overlays
                .filter({ $0.frame.contains(point) })
                .sorted(by: { $0.bounds.size == $1.bounds.size ? $0.hash > $1.hash : $0.bounds.size > $1.bounds.size })
        }
    }
    
    var isMouseInside: Bool {
        if let locationInWindow = window?.mouseLocationOutsideOfEventStream {
            let loc = convert(locationInWindow, from: nil)
            if bounds.contains(loc) {
                return true
            }
        }
        return false
    }
    
    override func mouseEntered(with event: NSEvent)      { updateAppearance(with: event.locationInWindow) }
    override func mouseMoved(with event: NSEvent)        { updateAppearance(with: event.locationInWindow) }
    override func mouseExited(with event: NSEvent)       { resetAppearance()                              }
    override func mouseDown(with event: NSEvent)         { updateAppearance(with: event.locationInWindow) }
    override func rightMouseDown(with event: NSEvent)    { updateAppearance(with: event.locationInWindow) }
    override func mouseUp(with event: NSEvent)           { updateAppearance(with: event.locationInWindow) }
    override func rightMouseUp(with event: NSEvent)      { updateAppearance(with: event.locationInWindow) }
    override func mouseDragged(with event: NSEvent)      { updateAppearance(with: event.locationInWindow) }
    override func rightMouseDragged(with event: NSEvent) { updateAppearance(with: event.locationInWindow) }
    override func scrollWheel(with event: NSEvent)       { updateAppearance(with: event.locationInWindow) }
    override func magnify(with event: NSEvent)           { updateAppearance(with: event.locationInWindow) }
    override func smartMagnify(with event: NSEvent)      { updateAppearance(with: event.locationInWindow) }
    
    func updateAppearance() {
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
        guard hasFocusingCursor else {
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
                if sceneState.manipulatingType != .forbidden {
                    sceneTool.manipulatingCursor.set()
                }
                else {
                    sceneTool.disabledCursor.set()
                }
            }
            else if let focusedOverlay = focusedOverlay,
                    let mouseLocation = locInWindow ?? window?.mouseLocationOutsideOfEventStream
            {
                let locInOverlay = focusedOverlay.convert(mouseLocation, from: nil)
                let direction = focusedOverlay.direction(at: locInOverlay)
                if let focusingCursor = sceneTool.focusingCursorForEditableDirection(direction) {
                    focusingCursor.set()
                } else {
                    sceneTool.normalCursor.set()
                }
            } else {
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
    
}

extension SceneOverlayView: DragEndpoint {
    
    // MARK: - Drag/Drop
    
    private func extractTagsFromDraggingInfo(_ draggingInfo: NSDraggingInfo) -> [DraggedTag]
    {
        var tags = [DraggedTag]()
        draggingInfo.enumerateDraggingItems(
            options: [],
            for: self,
            classes: [NSPasteboardItem.self],
            searchOptions: [:]
        ) { (dragItem, _, _) in
            if let obj = (dragItem.item as! NSPasteboardItem).propertyList(
                forType: TagListController.attachPasteboardType
            ) as? [[String: Any]] {
                obj.forEach({
                    tags.append(DraggedTag(dictionary: $0))
                })
            }
        }
        return tags
    }
    
    private func operationMaskOfDraggingTarget(
        _ draggingInfo: NSDraggingInfo,
        target: AnnotatorOverlay?
    ) -> NSDragOperation
    {
        let operationMask = draggingInfo.draggingSourceOperationMask
        guard target != nil else { return [] }
        if maximumTagPerItemEnabled {
            guard let targetOverlay = target, let targetItem = contentItem(of: targetOverlay) else {
                return []
            }
            let tagNamesToAppend = extractTagsFromDraggingInfo(draggingInfo).map({ $0.name })
            if maximumTagPerItem > 0 {
                if replaceSingleTagWhileDrop && maximumTagPerItem == 1 && targetItem.tags.count == 1 && tagNamesToAppend.count == 1 {
                    return operationMask.intersection([.link])
                }
                guard targetItem.tags.count + tagNamesToAppend.count <= maximumTagPerItem else { return [] }
            }
            guard !Set(tagNamesToAppend).isSubset(of: Set(targetItem.tags)) else { return [] }
        }
        return operationMask.intersection([.copy])
    }
    
    private func updateDraggingAppearance(with locInWindow: CGPoint?) {
        guard isMouseInside else { return }
        internalUpdateFocusAppearance(with: locInWindow)
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard case .idle = dragEndpointState else { return [] }
        guard (sender.draggingSource as? DragConnectionController)?.sourceEndpoint != nil else { return [] }
        updateDraggingAppearance(with: sender.draggingLocation)
        let operationMask = operationMaskOfDraggingTarget(
            sender,
            target: internalFocusedOverlay
        )
        if !operationMask.isEmpty {
            dragEndpointState = .target
        } else {
            dragEndpointState = .source
        }
        return operationMask
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard dragEndpointState != .idle else { return [] }
        guard (sender.draggingSource as? DragConnectionController)?.sourceEndpoint != nil else { return [] }
        updateDraggingAppearance(with: sender.draggingLocation)
        let operationMask = operationMaskOfDraggingTarget(
            sender,
            target: internalFocusedOverlay
        )
        if !operationMask.isEmpty {
            dragEndpointState = .target
        } else {
            dragEndpointState = .source
        }
        return operationMask
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        guard case .target = dragEndpointState else { return }
        resetAppearance()
        dragEndpointState = .idle
    }
    
    override func draggingEnded(_ sender: NSDraggingInfo) {
        guard case .target = dragEndpointState else { return }
        resetAppearance()
        dragEndpointState = .idle
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let focusedOverlay = internalFocusedOverlay,
              !operationMaskOfDraggingTarget(
                sender,
                target: focusedOverlay
              ).isEmpty else { return false }
        guard let origItem = contentItem(of: focusedOverlay) else { return false }
        guard let replItem = origItem.copy() as? ContentItem else { return false }
            
        guard let controller = sender.draggingSource as? DragConnectionController else { return false }
        controller.connect(to: self)
        
        if sender.draggingSourceOperationMask.contains(.link) {
            replItem.tags.removeAll(keepingCapacity: true)
        }
        
        let draggedTags = extractTagsFromDraggingInfo(sender)
        let draggedTagNames = draggedTags.map({ $0.name })
        replItem.tags.append(contentsOf: draggedTagNames)
        
        if let firstTag = replItem.firstTag,
           draggedTagNames.contains(firstTag),
           let firstUserInfo = draggedTags.first?.defaultUserInfo
        {
            var combinedUserInfo = replItem.userInfo ?? [:]
            combinedUserInfo.merge(firstUserInfo) { old, _ in old }
            replItem.userInfo = combinedUserInfo
        }
        
        if let _ = try? contentDelegate.updateContentItem(replItem) {
            return true
        }
        
        return false
    }
    
}

extension SceneOverlayView: SceneTracking {
    
    func sceneVisibleRectDidChange(_ sender: SceneScrollView?, to rect: CGRect, of magnification: CGFloat) {
        
    }
    
}
