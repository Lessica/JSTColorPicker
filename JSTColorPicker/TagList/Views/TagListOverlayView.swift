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
                sceneToolSource.resetSceneTool()
                setNeedsDisplay(bounds)
            }
        }
    }
    
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override var wantsDefaultClipping: Bool { false }
    
    public weak var dataSource: TagListSource!
    public weak var dragDelegate: TagListDragDelegate!
    
    public weak var sceneToolSource: SceneToolSource!
    private var sceneTool: SceneTool { return sceneToolSource!.sceneTool }
    
    public var tableRowHeight: CGFloat = 16.0
    private var highlightedRects: [CGRect]?
    
    private static let focusLineWidth: CGFloat = 2.0
    private static let focusLineColor = NSColor(white: 1.0, alpha: 1.0)
    
    private var hasAttachedSheet: Bool { window?.attachedSheet != nil }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layerContentsPlacement = .center
    }
    
    override func rightMouseDown(with event: NSEvent) {
        guard !hasAttachedSheet
            && dragDelegate.shouldPerformDragging
            && sceneTool == .selectionArrow
            && sceneToolSource.sceneToolEnabled
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
        
        guard dragDelegate.willPerformDragging(self) else {
            return
        }
        
        highlightedRects = dragDelegate
            .visibleRects(of: rowIndexes)
        
        let selectedTagNames = rowIndexes.compactMap({ dataSource.arrangedTags[$0].name })
        
        let controller = DragConnectionController(type: TagListController.attachPasteboardType)
        controller.trackDrag(forMouseDownEvent: event, in: self, with: selectedTagNames)
        
        setNeedsDisplay(bounds)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard !inLiveResize else { return }
        guard let rects = highlightedRects else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        ctx.setLineWidth(TagListOverlayView.focusLineWidth)
        ctx.setStrokeColor(TagListOverlayView.focusLineColor.cgColor)
        
        let outerRect = dirtyRect
            .insetBy(dx: 0.0, dy: 0.5)
            .offsetBy(dx: 0.0, dy: 0.5)
        for rect in rects.filter({ outerRect.intersects($0) }) {
            let innerRect = rect.intersection(outerRect)
            if innerRect.height > tableRowHeight + 2.0 {
                ctx.addRect(innerRect
                    .insetBy(dx: TagListOverlayView.focusLineWidth, dy: TagListOverlayView.focusLineWidth + 0.5)
                    .offsetBy(dx: 0.0, dy: -0.5)
                )
            } else {
                ctx.addRect(rect
                    .insetBy(dx: TagListOverlayView.focusLineWidth, dy: TagListOverlayView.focusLineWidth + 0.5)
                    .offsetBy(dx: 0.0, dy: -0.5)
                )
            }
        }
        
        ctx.strokePath()
    }
    
    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        needsDisplay = true
    }
    
}
