//
//  TagListOverlayView.swift
//  JSTColorPicker
//
//  Created by Darwin on 5/27/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

final class TagListOverlayView: NSView, DragEndpoint {
    
    var dragEndpointState: DragEndpointState = .idle {
        didSet {
            if dragEndpointState == .idle {
                highlightedRects = nil
                sceneToolSource.resetSceneTool()
                setNeedsDisplay(bounds)
            }
        }
    }
    
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override var wantsDefaultClipping: Bool { false }
    
    weak var dataSource: TagListSource!
    weak var dragDelegate: TagListDragDelegate!
    
    weak var sceneToolSource: SceneToolSource!
    private var sceneTool: SceneTool { return sceneToolSource!.sceneTool }
    
    var tableRowHeight: CGFloat = 20.0
    private var highlightedRects: [CGRect]?
    
    private static let focusLineWidth: CGFloat = 2.0
    private static let focusLineColor = NSColor(white: 1.0, alpha: 1.0)
    
    private var hasAttachedSheet: Bool { window?.attachedSheet != nil }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layerContentsPlacement = .scaleAxesIndependently
    }
    
    override func mouseDown(with event: NSEvent) {
        guard !hasAttachedSheet
                && dragDelegate.shouldPerformDragging(self, with: event)
        else {
            super.mouseDown(with: event)
            return
        }
        
        handleMouseDown(with: event)
    }
    
    override func rightMouseDown(with event: NSEvent) {
        guard !hasAttachedSheet
                && dragDelegate.shouldPerformDragging(self, with: event)
        else {
            super.rightMouseDown(with: event)
            return
        }
        
        handleMouseDown(with: event)
    }
    
    private func handleMouseDown(with event: NSEvent) {
        
        let locInOverlay = convert(event.locationInWindow, from: nil)
        let rowIndexes = dragDelegate.selectRow(
            at: locInOverlay,
            byExtendingSelection: false,
            byFocusingSelection: true
        )
        guard rowIndexes.count > 0 else {
            return
        }
        
        guard dragDelegate.willPerformDragging(self) else {
            return
        }
        
        highlightedRects = dragDelegate
            .visibleRects(of: rowIndexes)
        
        let selectedTagDictionaries: [[String: Any]] = rowIndexes.compactMap({
            let tag = dataSource.arrangedTags[$0]
            return DraggedTag(row: $0, name: tag.name, defaultUserInfo: tag.defaultUserInfo).dictionary
        })

        let controller = DragConnectionController(type: TagListController.attachPasteboardType)
        controller.trackDrag(forMouseDownEvent: event, in: self, with: selectedTagDictionaries)
        
        setNeedsDisplay(bounds)
    }

    override func scrollWheel(with event: NSEvent) {
        if dragEndpointState == .idle {
            super.scrollWheel(with: event)
        }
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
