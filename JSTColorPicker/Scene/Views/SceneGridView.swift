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
        layer?.addSublayer(backingLayer)
        
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layerContentsPlacement = .center
    }
    
    override var isFlipped: Bool { true }
    override var wantsDefaultClipping: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }  // disable user interactions
    override func cursorUpdate(with event: NSEvent) { }  // do not perform default behavior
    
    public var drawGridsInScene: Bool = false
    public var enableGPUAcceleration: Bool = true
    
    fileprivate static let minimumScaleOfGridDrawing  : CGFloat = 32.0
    fileprivate static let minimumScaleOfRasterization: CGFloat = 0.8
    fileprivate static let maximumScaleOfRasterization: CGFloat = 1.2
    fileprivate static let defaultGridLineWidth       : CGFloat = 1.0
    fileprivate static let defaultGridLineColor = CGColor(gray: 1.0, alpha: 0.3)
    
    fileprivate var shouldDrawGridsInScene: Bool = false
    fileprivate var gridWrappedPixelRect: PixelRect = .null
    fileprivate var gridRenderingArea: CGRect = .null
    
    
    // MARK: - CPU Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        
        // if condition not satisfy, do not draw
        guard !enableGPUAcceleration
            && !inLiveResize
            && drawGridsInScene
            && shouldDrawGridsInScene
            && !isHidden
            && !gridWrappedPixelRect.isEmpty
            && !gridRenderingArea.isEmpty
            else
        { return }
        
        // got context
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setShouldAntialias(false)
        ctx.setLineWidth(SceneGridView.defaultGridLineWidth)
        ctx.setStrokeColor(SceneGridView.defaultGridLineColor)
        
        // calculate size for single grid
        let gridSize = CGSize(
            width: gridRenderingArea.width / CGFloat(gridWrappedPixelRect.width),
            height: gridRenderingArea.height / CGFloat(gridWrappedPixelRect.height)
        )
        let maxX = CGFloat(gridWrappedPixelRect.width) * gridSize.width
        let maxY = CGFloat(gridWrappedPixelRect.height) * gridSize.height
        
        // ctx.saveGState()
        
        for x in 0 ..< gridWrappedPixelRect.width {
            let xPos = gridRenderingArea.minX + CGFloat(x) * gridSize.width
            ctx.move(to: CGPoint(x: xPos, y: 0.0))
            ctx.addLine(to: CGPoint(x: xPos, y: maxY))
        }
        for y in 0 ..< gridWrappedPixelRect.height {
            let yPos = gridRenderingArea.minY + CGFloat(y) * gridSize.height
            ctx.move(to: CGPoint(x: 0.0, y: yPos))
            ctx.addLine(to: CGPoint(x: maxX, y: yPos))
        }
        
        ctx.strokePath()
        
        // ctx.restoreGState()
        
    }
    
    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        guard !enableGPUAcceleration else {
            return
        }
        needsDisplay = true
    }
    
    
    // MARK: - Hidden Resets
    
    fileprivate weak var storedSceneView: SceneScrollView?
    fileprivate var storedRect: CGRect?
    fileprivate var storedMagnification: CGFloat?
    fileprivate var shouldPauseTracking: Bool = false
    
    override var isHidden: Bool {
        didSet {
            if !isHidden {
                if  let rect = storedRect,
                    let magnification = storedMagnification
                {
                    trackSceneBoundsChanged(storedSceneView, to: rect, of: magnification)
                }
            } else {
                storedSceneView = nil
                storedRect = nil
                storedMagnification = nil
            }
        }
    }
    
    
    // MARK: - Backing Layer
    
    private lazy var backingLayer: CAShapeLayer = {
        let shapeLayer = CAShapeLayer()
        shapeLayer.shouldRasterize = true
        shapeLayer.rasterizationScale = NSScreen.main?.backingScaleFactor ?? 1.0
        shapeLayer.allowsEdgeAntialiasing = false
        shapeLayer.lineWidth = SceneGridView.defaultGridLineWidth
        shapeLayer.strokeColor = SceneGridView.defaultGridLineColor
        shapeLayer.fillColor = nil
        shapeLayer.delegate = self
        return shapeLayer
    }()
    
    private var backingGridSize: CGSize?
    private var backingPixelSize: PixelSize?
    
}

extension SceneGridView: CALayerDelegate {
    
    // disable backingLayer's animations
    func action(for layer: CALayer, forKey event: String) -> CAAction? {
        return NSNull()
    }
    
}

extension SceneGridView: SceneTracking {
    
    
    // MARK: - GPU Drawing
    
    func trackSceneBoundsChanged(_ sender: SceneScrollView?, to rect: CGRect, of magnification: CGFloat) {
        
        guard let sceneView = sender else { return }
        
        shouldDrawGridsInScene = !rect.isEmpty && magnification >= SceneGridView.minimumScaleOfGridDrawing
        if drawGridsInScene && shouldDrawGridsInScene && !isHidden {
            
            // reset pause flag if necessary
            if shouldPauseTracking {
                shouldPauseTracking = false
            }
            
            // update draw areas, and positions
            gridWrappedPixelRect = rect.smallestWrappingPixelRect
            guard !gridWrappedPixelRect.isEmpty else { return }
            
            gridRenderingArea = sceneView
                .convertFromDocumentView(gridWrappedPixelRect.toCGRect())
                .offsetBy(-sceneView.alternativeBoundsOrigin)
            guard gridRenderingArea.width > 0 && gridRenderingArea.height > 0 else { return }
            
            // perform drawing in next loop
            if !enableGPUAcceleration {
                
                setNeedsDisplay(bounds)
                
            } else {
                
                // calculate size for single grid
                let gridSize = CGSize(
                    width: gridRenderingArea.width / CGFloat(gridWrappedPixelRect.width),
                    height: gridRenderingArea.height / CGFloat(gridWrappedPixelRect.height)
                )
                
                if  backingLayer.path != nil,
                    let backingGridSize = backingGridSize,
                    (
                        SceneGridView.minimumScaleOfRasterization...SceneGridView.maximumScaleOfRasterization ~= (gridSize.width / backingGridSize.width)
                        && SceneGridView.minimumScaleOfRasterization...SceneGridView.maximumScaleOfRasterization ~= (gridSize.height / backingGridSize.height)
                    ),
                    let backingPixelSize = backingPixelSize, (gridWrappedPixelRect.width <= backingPixelSize.width && gridWrappedPixelRect.height <= backingPixelSize.height)
                {
                    backingLayer.transform = CATransform3DConcat(
                        CATransform3DMakeScale(gridSize.width / backingGridSize.width, gridSize.height / backingGridSize.height, 1.0),
                        CATransform3DMakeTranslation(gridRenderingArea.minX, gridRenderingArea.minY, 0.0)
                    )
                }
                else
                {
                    let pixelSize = PixelSize(width: gridWrappedPixelRect.width + 1, height: gridWrappedPixelRect.height + 1)
                    
                    let maxX = CGFloat(pixelSize.width) * gridSize.width
                    let maxY = CGFloat(pixelSize.height) * gridSize.height
                    let shapePath = CGMutablePath()
                    for x in 0 ..< pixelSize.width {
                        let xPos = CGFloat(x) * gridSize.width
                        shapePath.move(to: CGPoint(x: xPos, y: 0.0))
                        shapePath.addLine(to: CGPoint(x: xPos, y: maxY))
                    }
                    for y in 0 ..< pixelSize.height {
                        let yPos = CGFloat(y) * gridSize.height
                        shapePath.move(to: CGPoint(x: 0.0, y: yPos))
                        shapePath.addLine(to: CGPoint(x: maxX, y: yPos))
                    }
                    
                    backingLayer.path = shapePath
                    debugPrint("replaced path: \(shapePath)")
                    
                    backingGridSize = gridSize
                    backingPixelSize = pixelSize
                    
                    backingLayer.transform = CATransform3DMakeTranslation(gridRenderingArea.minX, gridRenderingArea.minY, 0.0)
                }
                
            }
            
        }
        else {
            
            // clear current core graphics context if necessary
            if !shouldPauseTracking {
                shouldPauseTracking = true
                
                setNeedsDisplay(bounds)
                if backingLayer.path != nil {
                    backingLayer.path = nil
                }
            }
            
            // store unused values
            storedSceneView = sceneView
            storedRect = rect
            storedMagnification = magnification
            
        }
        
    }
    
}
