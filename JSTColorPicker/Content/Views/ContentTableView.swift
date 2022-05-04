//
//  ContentTableView.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/21/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol ContentTableViewResponder: AnyObject {
    func tableViewAction(_ sender: ContentTableView)
    func tableViewDoubleAction(_ sender: ContentTableView)
}

final class ContentTableView: NSTableView, UndoProxy {

    override var isFlipped            : Bool { true }
    
    weak var overlayView              : ContentOverlayView?
    weak var contentDelegate          : ContentActionResponder!
    weak var contentItemSource        : ContentItemSource?
    weak var tableViewResponder       : ContentTableViewResponder?
    
    private var hasAttachedSheet      : Bool { window?.attachedSheet != nil }
    
    var contextUndoManager            : UndoManager?
    override var undoManager          : UndoManager? { contextUndoManager }
    
    var maximumTagPerItem             : Int = 0
    var maximumTagPerItemEnabled      : Bool = false
    var replaceSingleTagWhileDrop     : Bool = false
    
    var dragEndpointState             : DragEndpointState = .idle
    private var currentFocusedIndex  : Int?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        registerForDraggedTypes([TagListController.attachPasteboardType])
    }
    
    override func menu(for event: NSEvent) -> NSMenu? {
        guard !hasAttachedSheet else { return nil }
        return super.menu(for: event)
    }
    
    override func keyDown(with event: NSEvent) {
        guard let specialKey = event.specialKey else {
            super.keyDown(with: event)
            return
        }
        let flags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting(.option)
        if flags.isEmpty && (specialKey == .carriageReturn || specialKey == .enter)
        {
            tableViewResponder?.tableViewDoubleAction(self)
            return
        }
        super.keyDown(with: event)
    }
    
    override func rightMouseDown(with event: NSEvent) {
        if row(at: convert(event.locationInWindow, from: nil)) < 0 {
            deselectAll(nil)
        }
        super.rightMouseDown(with: event)
    }

    override var gridColor: NSColor {
        get { NSColor.separatorColor }
        set { }
    }
}

extension ContentTableView: DragEndpoint {
    
    var isMouseInside: Bool {
        if let locationInWindow = window?.mouseLocationOutsideOfEventStream {
            let loc = convert(locationInWindow, from: nil)
            if bounds.contains(loc) {
                return true
            }
        }
        return false
    }
    
    private func visibleRects(of rowIndexes: IndexSet) -> [CGRect] {
        guard let overlayView = overlayView else { return [] }
        var rects = [CGRect]()
        var prevRect: CGRect = .null
        for rowIndex in rowIndexes {
            let rect = rect(ofRow: rowIndex)
            if !rect.offsetBy(dx: 0.0, dy: -0.1)
                .intersects(prevRect)
            {
                if !prevRect.isNull { rects.append(prevRect) }
                prevRect = rect
            } else {
                prevRect = prevRect.union(rect)
            }
        }
        if !prevRect.isNull { rects.append(prevRect) }
        return rects.map({ convert($0, to: overlayView) })
    }
    
    private func focusedIndex(at locInWindow: CGPoint?) -> Int? {
        
        guard isMouseInside else { return nil }
        
        guard let mouseLocation: CGPoint = locInWindow ?? window?.mouseLocationOutsideOfEventStream
        else { return nil }
        
        let loc = convert(mouseLocation, from: nil)
        let row = row(at: loc)
        
        return row >= 0 ? row : nil
    }
    
    private func updateDraggingAppearance(for row: Int?) {
        if let row = row, row >= 0, dragEndpointState != .idle && !dragEndpointState.isForbidden {
            // highlight row
            overlayView?.highlightedRects = visibleRects(of: IndexSet(integer: row))
        } else {
            overlayView?.highlightedRects = nil
        }
    }
    
    private func resetAppearance() {
        // reset highlights
        overlayView?.highlightedRects = nil
    }
    
    private func operationMaskOfDraggingInfo(
        _ draggingInfo: NSDraggingInfo,
        targetIndex: Int?,
        forbiddenReason: inout String?
    ) -> NSDragOperation
    {
        let operationMask = draggingInfo.draggingSourceOperationMask
        
        guard targetIndex != nil,
              let targetIndex = targetIndex,
              let targetItem = contentItemSource?.contentItem(at: targetIndex)
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
                
                func localizedString(describing tagNames: [String], forItem item: ContentItem) -> String {
                    if tagNames.isEmpty {
                        return String(
                            format: NSLocalizedString("tags in item #%ld", comment: "localizedString(describing:)"),
                            item.id
                        )
                    } else if tagNames.count == 1 {
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
                        let priorString = localizedString(describing: targetItem.tags.elements, forItem: targetItem)
                        let newString = localizedString(describing: tagNamesToAppend, forItem: targetItem)
                        
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
                        let priorString = localizedString(describing: targetItem.tags.elements, forItem: targetItem)
                        let newString = localizedString(describing: tagNamesToAppend, forItem: targetItem)
                        
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
        
        let focusedIndex = focusedIndex(at: sender.draggingLocation)
        
        var forbiddenReason: String?
        let operationMask = operationMaskOfDraggingInfo(sender,
                                                        targetIndex: focusedIndex,
                                                        forbiddenReason: &forbiddenReason)
        if operationMask.contains(.forbidden) {
            dragEndpointState = .forbidden(reason: forbiddenReason ?? "")
        } else if !operationMask.isEmpty {
            dragEndpointState = .target
        } else {
            dragEndpointState = .captured
        }
        
        updateDraggingAppearance(for: focusedIndex)
        
        currentFocusedIndex = focusedIndex
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
        
        if dragEndpointState != .idle {
            dragEndpointState = .idle
        }
        
        resetAppearance()
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        
        guard let focusedIndex = currentFocusedIndex else { return false }
        
        var forbiddenReason: String?
        let operationMask = operationMaskOfDraggingInfo(sender,
                                                        targetIndex: focusedIndex,
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
        
        guard let origItem = contentItemSource?.contentItem(at: focusedIndex) else { return false }
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
