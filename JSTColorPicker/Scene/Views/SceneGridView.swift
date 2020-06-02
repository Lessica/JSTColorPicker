//
//  SceneGridView.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/28/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class SceneGridView: NSView {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layerContentsPlacement = .center
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }  // disable user interactions
    
    override func cursorUpdate(with event: NSEvent) {
        // do not perform default behavior
    }
    
    var drawGridsInScene: Bool = false
    fileprivate var shouldDrawGridsInScene: Bool = false
    fileprivate static let minimumMagnificationForGridRendering: CGFloat = 32.0
    fileprivate static let gridLineWidth: CGFloat = 1.0
    fileprivate static let gridLineColor = NSColor(white: 1.0, alpha: 0.3)
    fileprivate var gridWrappedPixelRect: PixelRect = .null
    fileprivate var gridRenderingArea: CGRect = .null
    
    override func draw(_ dirtyRect: NSRect) {
        guard drawGridsInScene && shouldDrawGridsInScene else { return }
        guard !gridWrappedPixelRect.isEmpty else { return }
        guard !gridRenderingArea.isEmpty else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setAllowsAntialiasing(false)
        
        let gridSize = CGSize(
            width: gridRenderingArea.width / CGFloat(gridWrappedPixelRect.width),
            height: gridRenderingArea.height / CGFloat(gridWrappedPixelRect.height)
        )
        
        // ctx.saveGState()
        
        ctx.setLineWidth(SceneGridView.gridLineWidth)
        ctx.setStrokeColor(SceneGridView.gridLineColor.cgColor)
        for x in 0 ..< gridWrappedPixelRect.width {
            for y in 0 ..< gridWrappedPixelRect.height {
                ctx.addRect(CGRect(
                    origin: gridRenderingArea.origin.offsetBy(dx: CGFloat(x) * gridSize.width, dy: CGFloat(y) * gridSize.height),
                    size: gridSize
                ).intersection(dirtyRect))
            }
        }
        ctx.strokePath()
        
        // ctx.restoreGState()
    }
    
}

extension SceneGridView: SceneTracking {
    
    func trackSceneBoundsChanged(_ sender: SceneScrollView?, to rect: CGRect, of magnification: CGFloat) {
        guard let sceneView = sender else { return }
        shouldDrawGridsInScene = !rect.isEmpty && magnification >= SceneGridView.minimumMagnificationForGridRendering
        if drawGridsInScene && shouldDrawGridsInScene {
            gridWrappedPixelRect = rect.smallestWrappingPixelRect
            gridRenderingArea = sceneView.convertFromDocumentView(gridWrappedPixelRect.toCGRect()).offsetBy(-sceneView.alternativeBoundsOrigin)
        }
        setNeedsDisplay()
    }
    
}
