//
//  SceneOverlayView.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/29/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

final class SceneOverlayView: NSView {
    
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
    private weak var currentFocusedOverlay: AnnotatorOverlay?
    
    var editableDirection: EditableOverlay.Direction { focusedOverlay != nil ? currentEditableDirection : .none }
    private var currentEditableDirection: EditableOverlay.Direction = .none
    
    var hasFocusingCursor: Bool {
        return sceneTool.hasFocusingCursorWithoutDragging
    }
    var isFocused: Bool {
        return hasFocusingCursor ? currentFocusedOverlay != nil : false
    }
    var focusedOverlay: AnnotatorOverlay? {
        return hasFocusingCursor ? currentFocusedOverlay : nil
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
    
    var dragEndpointState: DragEndpointState = .idle
    var nextFocusingStyle: Overlay.FocusingStyle {
        !dragEndpointState.isForbidden ? .normal : .forbidden
    }
    
    var maximumTagPerItem: Int = 0
    var maximumTagPerItemEnabled: Bool = false
    var replaceSingleTagWhileDrop: Bool = false
    
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
        _updateFocusingAppearance(with: locInWindow)
        _updateCursorAppearance(with: locInWindow)
    }
    
    private func resetAppearance() {
        _resetFocusingAppearance()
        _resetCursorAppearance()
    }
    
    /// not for dragging
    private func _updateFocusingAppearance(with locInWindow: CGPoint?) {
        guard hasFocusingCursor else {
            _resetFocusingAppearance()
            return
        }
        
        guard let mouseLocation: CGPoint = locInWindow ?? window?.mouseLocationOutsideOfEventStream else { return }
        
        let loc = convert(mouseLocation, from: nil)
        if let overlay = self.frontmostOverlay(at: loc) {
            if let focusedOverlay = self.currentFocusedOverlay {
                if overlay != focusedOverlay {
                    focusedOverlay.isFocused = false
                    focusedOverlay.setNeedsDisplay()
                    overlay.isFocused = true
                    overlay.setNeedsDisplay()
                    self.currentFocusedOverlay = overlay
                }
            }
            else {
                overlay.isFocused = true
                overlay.setNeedsDisplay()
                self.currentFocusedOverlay = overlay
            }
        }
        else {
            _resetFocusingAppearance()
        }
    }
    
    private func _updateCursorAppearance(with locInWindow: CGPoint?) {
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
    
    private func _resetFocusingAppearance() {
        if let focusedOverlay = self.currentFocusedOverlay {
            focusedOverlay.isFocused = false
            focusedOverlay.setNeedsDisplay()
            self.currentFocusedOverlay = nil
        }
    }
    
    private func _resetCursorAppearance() {
        SceneTool.arrowCursor.set()
    }
    
}

extension SceneOverlayView: DragEndpoint {
    
    // MARK: - Drag/Drop
    
    private func operationMaskOfDraggingInfo(
        _ draggingInfo: NSDraggingInfo,
        targetOverlay: AnnotatorOverlay?,
        forbiddenReason: inout String?
    ) -> NSDragOperation
    {
        let operationMask = draggingInfo.draggingSourceOperationMask
        
        guard targetOverlay != nil,
              let targetOverlay = targetOverlay,
              let targetItem = contentItem(of: targetOverlay)
        else {
            // no content item
            return []
        }
        
        let optionPressed = NSEvent.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .contains(.option)
        
        let tagNamesToAppend = DraggedTag.draggedTagsFromDraggingInfo(draggingInfo, forView: self).map({ $0.name })
        if maximumTagPerItemEnabled {
            if maximumTagPerItem > 0 {
                if replaceSingleTagWhileDrop
                    && maximumTagPerItem == 1
                    && targetItem.tags.count == 1
                    && tagNamesToAppend.count == 1
                {
                    if tagNamesToAppend.first == targetItem.firstTag {
                        // no changes
                        forbiddenReason = NSLocalizedString("No changes has been made.", comment: "forbiddenReason")
                        return [.forbidden]
                    }
                    
                    // move only
                    return operationMask.intersection([.move])
                }
                
                func localizedString(describing tagNames: [String]) -> String {
                    if tagNames.count == 1 {
                        return String(
                            format: NSLocalizedString("tag “%@”", comment: "localizedString(describing:)"), tagNames.first!)
                    } else {
                        return String(
                            format: NSLocalizedString("“%@” and other %ld tags", comment: "localizedString(describing:)"),
                            tagNames.first!, tagNames.count - 1
                        )
                    }
                }
                
                if optionPressed {
                    
                    // copy limit
                    guard targetItem.tags.count + tagNamesToAppend.count <= maximumTagPerItem
                    else {
                        // reaches limit
                        let priorString = localizedString(describing: targetItem.tags.elements)
                        let newString = localizedString(describing: tagNamesToAppend)
                        
                        forbiddenReason = String(
                            format: NSLocalizedString("Will add %@ to existing %@, while maximum tag per item is set to %ld.", comment: "forbiddenReason"),
                            newString, priorString, maximumTagPerItem
                        )
                        return [.forbidden]
                    }
                } else {
                    
                    // move limit
                    guard tagNamesToAppend.count <= maximumTagPerItem
                    else {
                        // reaches limit
                        let priorString = localizedString(describing: targetItem.tags.elements)
                        let newString = localizedString(describing: tagNamesToAppend)
                        
                        forbiddenReason = String(
                            format: NSLocalizedString("Will replace prior %@ with new %@, while maximum tag per item is set to %ld.", comment: "forbiddenReason"),
                            priorString, newString, maximumTagPerItem
                        )
                        return [.forbidden]
                    }
                }
            }
        }
        
        guard !Set(tagNamesToAppend).isSubset(of: Set(targetItem.tags))
        else {
            // duplicated
            forbiddenReason = NSLocalizedString("No changes has been made.", comment: "forbiddenReason")
            return [.forbidden]
        }
        
        // option pressed -> copy
        // option not pressed -> move
        return optionPressed ? operationMask.intersection([.copy]) : operationMask.intersection([.move])
    }
    
    /// for dragging only
    private func focusedOverlay(at locInWindow: CGPoint?) -> AnnotatorOverlay? {
        
        guard isMouseInside else { return nil }
        
        guard let mouseLocation: CGPoint = locInWindow ?? window?.mouseLocationOutsideOfEventStream
        else { return nil }
        
        let loc = convert(mouseLocation, from: nil)
        guard let overlay = self.frontmostOverlay(at: loc)
        else {
            // reset
            if let focusedOverlay = self.currentFocusedOverlay {
                focusedOverlay.isFocused = false
            }
            return nil
        }
        
        if let focusedOverlay = self.currentFocusedOverlay {
            if overlay != focusedOverlay {
                focusedOverlay.isFocused = false
                overlay.isFocused = true
            }
        } else {
            overlay.isFocused = true
        }
        
        return overlay
    }
    
    private func updateDraggingAppearance(for overlay: AnnotatorOverlay?) {
        
        if let overlay = overlay {
            if let focusedOverlay = self.currentFocusedOverlay {
                if overlay != focusedOverlay {
                    focusedOverlay.setNeedsDisplay()
                    
                    overlay.focusingStyle = nextFocusingStyle
                    overlay.setNeedsDisplay()
                } else if overlay.focusingStyle != nextFocusingStyle {
                    
                    overlay.focusingStyle = nextFocusingStyle
                    overlay.setNeedsDisplay()
                }
            } else {
                
                overlay.focusingStyle = nextFocusingStyle
                overlay.setNeedsDisplay()
            }
        } else {
            
            // reset
            if let focusedOverlay = self.currentFocusedOverlay {
                focusedOverlay.setNeedsDisplay()
            }
        }
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard case .idle = dragEndpointState else { return [] }
        return draggingEnteredOrUpdated(sender)
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard dragEndpointState != .idle else { return [] }
        return draggingEnteredOrUpdated(sender)
    }
    
    private func draggingEnteredOrUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        
        guard let connectionController = sender.draggingSource as? DragConnectionController else { return [] }
        guard connectionController.sourceEndpoint != nil else { return [] }
        connectionController.testConnection(to: self)
        
        let focusedOverlay = focusedOverlay(at: sender.draggingLocation)
        
        var forbiddenReason: String?
        let operationMask = operationMaskOfDraggingInfo(sender,
                                                        targetOverlay: currentFocusedOverlay,
                                                        forbiddenReason: &forbiddenReason)
        if operationMask.contains(.forbidden) {
            dragEndpointState = .forbidden(reason: forbiddenReason ?? "")
        } else if !operationMask.isEmpty {
            dragEndpointState = .target
        } else {
            dragEndpointState = .captured
        }
        
        updateDraggingAppearance(for: focusedOverlay)
        
        currentFocusedOverlay = focusedOverlay
        return operationMask
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        draggingExitedOrEnded(sender)
    }
    
    override func draggingEnded(_ sender: NSDraggingInfo) {
        draggingExitedOrEnded(sender)
    }
    
    private func draggingExitedOrEnded(_ sender: NSDraggingInfo?) {
        
        if let connectionController = sender?.draggingSource as? DragConnectionController,
           connectionController.sourceEndpoint != nil
        {
            connectionController.testConnection()
        }
        
        resetAppearance()
        
        if dragEndpointState != .idle {
            dragEndpointState = .idle
        }
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let focusedOverlay = currentFocusedOverlay else { return false }
        
        var forbiddenReason: String?
        let operationMask = operationMaskOfDraggingInfo(sender,
                                                        targetOverlay: focusedOverlay,
                                                        forbiddenReason: &forbiddenReason)
        
        guard !operationMask.isEmpty && !operationMask.contains(.forbidden) else {
            if let forbiddenReason = forbiddenReason {
                let helpManager = NSHelpManager.shared
                helpManager.setContextHelp(NSAttributedString(string: forbiddenReason, attributes: [
                    .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                ]), for: self)
                helpManager.showContextHelp(for: self, locationHint: NSEvent.mouseLocation)
                helpManager.removeContextHelp(for: self)
            }
            return false
        }
        
        guard let origItem = contentItem(of: focusedOverlay) else { return false }
        guard let replItem = origItem.copy() as? ContentItem else { return false }
            
        guard let connectionController = sender.draggingSource as? DragConnectionController else { return false }
        guard connectionController.sourceEndpoint != nil else { return false }
        connectionController.doConnection(to: self)
        
        if operationMask.contains(.move) {
            replItem.tags.removeAll(keepingCapacity: true)
        }
        
        let draggedTags = DraggedTag.draggedTagsFromDraggingInfo(sender, forView: self)
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
