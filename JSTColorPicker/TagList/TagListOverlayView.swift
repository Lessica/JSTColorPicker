//
//  TagListOverlayView.swift
//  JSTColorPicker
//
//  Created by Darwin on 5/27/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class TagListOverlayView: NSView, DragEndpoint {
    
    var state: DragEndpointState = .idle {
        didSet {
            if state == .idle {
                sceneToolDataSource!.resetSceneTool()
            }
        }
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    public weak var dataSource: TagListDataSource?
    public weak var dragDelegate: TagListDragDelegate?
    
    public weak var sceneToolDataSource: SceneToolDataSource?
    fileprivate var sceneTool: SceneTool { return sceneToolDataSource!.sceneTool }
    
    override func rightMouseDown(with event: NSEvent) {
        guard let dragDelegate = dragDelegate, let dataSource = dataSource else {
            super.rightMouseDown(with: event)
            return
        }
        
        guard dragDelegate.canPerformDrag && sceneTool == .selectionArrow else {
            super.rightMouseDown(with: event)
            return
        }
        
        let locInOverlay = convert(event.locationInWindow, from: nil)
        let rowIndexes = dragDelegate.selectedRowIndexes(at: locInOverlay, shouldHighlight: true)
        let selectedTagNames = rowIndexes.compactMap({ dataSource.managedTags?[$0].name })
        
        let controller = DragConnectionController(type: TagListController.attachPasteboardType)
        controller.trackDrag(forMouseDownEvent: event, in: self, with: selectedTagNames)
    }
    
}
