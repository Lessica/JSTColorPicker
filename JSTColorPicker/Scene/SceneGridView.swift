//
//  SceneGridView.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/28/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class SceneGridView: NSView {
    
    override var isFlipped: Bool {
        return true
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }  // disable user interactions
    
    override func cursorUpdate(with event: NSEvent) {
        // do not perform default behavior
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = true
        // canDrawConcurrently = true
    }
    
    fileprivate static let minimumMagnificationForGridRendering: CGFloat = 32.0
    fileprivate static let gridLineWidth: CGFloat = 1.0
    fileprivate static let gridLineColor = NSColor.textBackgroundColor
    fileprivate var enableGridRendering: Bool = false
    fileprivate var gridWrappedPixelRect: PixelRect = .null
    fileprivate var gridRenderingArea: CGRect = .null
    
    override func draw(_ dirtyRect: NSRect) {
        guard enableGridRendering else { return }
        guard !gridWrappedPixelRect.isNull else { return }
        guard !gridRenderingArea.isNull else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        let gridWidth = gridRenderingArea.width / CGFloat(gridWrappedPixelRect.width)
        let gridHeight = gridRenderingArea.height / CGFloat(gridWrappedPixelRect.height)
        let gridSize = CGSize(width: gridWidth, height: gridHeight)
        
        // ctx.saveGState()
        ctx.setLineWidth(SceneGridView.gridLineWidth)
        ctx.setStrokeColor(SceneGridView.gridLineColor.cgColor)
        
        for x in 0 ..< gridWrappedPixelRect.width {
            for y in 0 ..< gridWrappedPixelRect.height {
                let gridRect = CGRect(origin: gridRenderingArea.origin.offsetBy(dx: CGFloat(x) * gridWidth, dy: CGFloat(y) * gridHeight), size: gridSize)
                ctx.addRect(gridRect)
            }
        }
        ctx.strokePath()
        
        // ctx.restoreGState()
    }
    
}

extension CGRect {
    
    var smallestWrappingPixelRect: PixelRect {
        return PixelRect(point1: CGPoint(x: floor(minX), y: floor(minY)), point2: CGPoint(x: ceil(maxX), y: ceil(maxY)))
    }
    
    var largestWrappedPixelRect: PixelRect {
        return PixelRect(point1: CGPoint(x: ceil(minX), y: ceil(minY)), point2: CGPoint(x: floor(maxX), y: floor(maxY)))
    }
    
}

extension SceneGridView: SceneTracking {
    
    func trackSceneBoundsChanged(_ sender: Any, to rect: CGRect, of magnification: CGFloat) {
        guard let sceneView = sender as? SceneScrollView else { return }
        enableGridRendering = !rect.isNull && magnification >= SceneGridView.minimumMagnificationForGridRendering
        if enableGridRendering {
            gridWrappedPixelRect = rect.smallestWrappingPixelRect
            gridRenderingArea = sceneView.convertFromDocumentView(gridWrappedPixelRect.toCGRect()).offsetBy(-SceneScrollView.alternativeBoundsOrigin)
        }
        setNeedsDisplay()
    }
    
}
