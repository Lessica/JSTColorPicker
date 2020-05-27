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
    
    public weak var sceneToolDataSource: SceneToolDataSource?
    fileprivate var sceneTool: SceneTool { return sceneToolDataSource!.sceneTool }
    
    override func rightMouseDown(with event: NSEvent) {
        guard sceneTool == .selectionArrow else {
            super.rightMouseDown(with: event)
            return
        }
        
        // TODO: change selection, highlight table view row, and get its object
        
        let controller = ConnectionDragController(type: TagListController.dragDropType)
        controller.trackDrag(forMouseDownEvent: event, in: self, with: "\(self)")
    }
    
}
