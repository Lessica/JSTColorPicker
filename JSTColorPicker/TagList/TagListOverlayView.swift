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
                highlightedRects = nil
                sceneToolDataSource.resetSceneTool()
                setNeedsDisplay()
            }
        }
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    public weak var dataSource: TagListDataSource!
    public weak var dragDelegate: TagListDragDelegate!
    
    public weak var sceneToolDataSource: SceneToolDataSource!
    fileprivate var sceneTool: SceneTool { return sceneToolDataSource!.sceneTool }
    
    fileprivate var highlightedRects: [CGRect]?
    
    fileprivate static let focusLineWidth: CGFloat = 2.0
    fileprivate static let focusLineColor = NSColor(white: 1.0, alpha: 1.0)
    
    override func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layerContentsPlacement = .center
    }
    
    override func rightMouseDown(with event: NSEvent) {
        guard dragDelegate.canPerformDrag
            && sceneTool == .selectionArrow
            && sceneToolDataSource.sceneToolEnabled
            else
        {
            super.rightMouseDown(with: event)
            return
        }
        
        let locInOverlay = convert(event.locationInWindow, from: nil)
        let rowIndexes = dragDelegate.selectedRowIndexes(at: locInOverlay, shouldHighlight: true)
        guard rowIndexes.count > 0 else {
            //super.rightMouseDown(with: event)
            return
        }
        
        highlightedRects = dragDelegate
            .visibleRects(of: rowIndexes)
        
        let selectedTagNames = rowIndexes.compactMap({ dataSource.arrangedTags[$0].name })
        
        let controller = DragConnectionController(type: TagListController.attachPasteboardType)
        controller.trackDrag(forMouseDownEvent: event, in: self, with: selectedTagNames)
        
        setNeedsDisplay()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let rects = highlightedRects else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        ctx.setLineWidth(TagListOverlayView.focusLineWidth)
        ctx.setStrokeColor(TagListOverlayView.focusLineColor.cgColor)
        rects
            .filter({ dirtyRect.intersects($0) })
            .forEach({
                ctx.addRect($0
                    .insetBy(dx: TagListOverlayView.focusLineWidth, dy: TagListOverlayView.focusLineWidth + 0.5)
                    .offsetBy(dx: 0.0, dy: -0.5)
                )
            })
        ctx.strokePath()
    }
    
}
