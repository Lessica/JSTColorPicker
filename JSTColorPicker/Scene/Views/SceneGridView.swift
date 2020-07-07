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
        if let compositingFilter = CIFilter(name: "CIOverlayBlendMode") {
            layer?.compositingFilter = compositingFilter
        }
        
        enableGPUAcceleration = UserDefaults.standard[.enableGPUAcceleration]
        if enableGPUAcceleration { layer?.addSublayer(backingLayer) }
    }
    
    override var isFlipped: Bool { true }
    override var wantsDefaultClipping: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }  // disable user interactions
    override func cursorUpdate(with event: NSEvent) { }  // do not perform default behavior
    
    public var drawGridsInScene: Bool = false
    public var enableGPUAcceleration: Bool = true
    
    private static let minimumScaleOfGridDrawing    : CGFloat = 32.0
    private static let minimumScaleOfRasterization  : CGFloat = 0.8
    private static let maximumScaleOfRasterization  : CGFloat = 1.25
    private static let defaultGridLineWidth         : CGFloat = 1.0
    private static let defaultGridLineColor         = CGColor(gray: 1.0, alpha: 1.0)
    private static let defaultCachedSquareSize      = CGSize(width: 256.0, height: 256.0)
    
    private var wrappedPixelRect: PixelRect = .null
    private var wrappedRenderingArea: CGRect = .null
    private var scaleSatisfiedGridDrawing: Bool = false
    private var positionSatisfiedGridDrawing: Bool {
        !wrappedPixelRect.isEmpty
            && !wrappedRenderingArea.isEmpty
            && wrappedRenderingArea.width > 0
            && wrappedRenderingArea.height > 0
    }
    
    
    // MARK: - CPU Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        
        // if condition not satisfy, do not draw
        guard !enableGPUAcceleration
            && !inLiveResize
            && drawGridsInScene
            && scaleSatisfiedGridDrawing
            && positionSatisfiedGridDrawing
            && !isHidden
            else
        {
            debugPrint("cleared draw(_:)")
            return
        }
        
        debugPrint("painted draw(_:)")
        
        // got context
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setShouldAntialias(true)
        ctx.setLineWidth(SceneGridView.defaultGridLineWidth)
        ctx.setStrokeColor(SceneGridView.defaultGridLineColor)
        
        // calculate size for single grid
        let gridSize = CGSize(
            width: wrappedRenderingArea.width / CGFloat(wrappedPixelRect.width),
            height: wrappedRenderingArea.height / CGFloat(wrappedPixelRect.height)
        )
        let maxX = wrappedRenderingArea.minX + CGFloat(wrappedPixelRect.width) * gridSize.width
        let maxY = wrappedRenderingArea.minY + CGFloat(wrappedPixelRect.height) * gridSize.height
        
        // ctx.saveGState()
        
        for x in 1 ..< wrappedPixelRect.width {
            let xPos = wrappedRenderingArea.minX + CGFloat(x) * gridSize.width
            ctx.move(to: CGPoint(x: xPos, y: wrappedRenderingArea.minY))
            ctx.addLine(to: CGPoint(x: xPos, y: maxY))
        }
        for y in 1 ..< wrappedPixelRect.height {
            let yPos = wrappedRenderingArea.minY + CGFloat(y) * gridSize.height
            ctx.move(to: CGPoint(x: wrappedRenderingArea.minX, y: yPos))
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
    
    private weak var storedSceneView: SceneScrollView?
    private var storedRect: CGRect?
    private var storedMagnification: CGFloat?  // not used
    private var shouldPauseTracking: Bool = false
    
    override var isHidden: Bool {
        didSet {
            if !isHidden {
                
                if  let rect = storedRect,
                    let magnification = storedMagnification
                {
                    trackVisibleRectChanged(storedSceneView, to: rect, of: magnification)
                }
                
            } else {
                
                storedSceneView = nil
                storedRect = nil
                storedMagnification = nil
                
                backingGridSize = nil
                backingPixelSize = nil
                
            }
        }
    }
    
    
    // MARK: - Backing Layer
    
    private lazy var backingLayer: CAShapeLayer = {
        let shapeLayer = CAShapeLayer()
        shapeLayer.shouldRasterize = true
        shapeLayer.rasterizationScale = NSScreen.main?.backingScaleFactor ?? 1.0
        shapeLayer.allowsEdgeAntialiasing = true
        shapeLayer.minificationFilter = .linear
        shapeLayer.magnificationFilter = .trilinear
        shapeLayer.lineWidth = SceneGridView.defaultGridLineWidth
        shapeLayer.strokeColor = SceneGridView.defaultGridLineColor
        shapeLayer.fillColor = nil
        shapeLayer.delegate = self
        return shapeLayer
    }()
    
    private var backingGridSize: CGSize?
    private var backingPixelSize: PixelSize?
    
}

extension SceneGridView: CALayerDelegate {}

extension SceneGridView: SceneTracking {
    
    
    // MARK: - GPU Drawing
    
    func trackVisibleRectChanged(_ sender: SceneScrollView?, to rect: CGRect, of magnification: CGFloat) {
        
        guard let sceneView = sender else { return }
        
        scaleSatisfiedGridDrawing = magnification >= SceneGridView.minimumScaleOfGridDrawing
        var drawable: Bool = drawGridsInScene && scaleSatisfiedGridDrawing && !isHidden
        
        if drawable {
            // update draw areas, and positions
            let wrappedRestrictedRect = rect.intersection(sceneView.wrapperBounds)
            if !rect.isEmpty && !wrappedRestrictedRect.isEmpty {
                wrappedPixelRect = wrappedRestrictedRect.smallestWrappingPixelRect
                wrappedRenderingArea = sceneView
                    .convertFromDocumentView(wrappedPixelRect.toCGRect())
                    .offsetBy(-sceneView.alternativeBoundsOrigin)
                drawable = enableGPUAcceleration ? positionSatisfiedGridDrawing : true
            } else {
                wrappedPixelRect = .null
                wrappedRenderingArea = .null
                drawable = false
            }
        }
            
        if drawable {
            
            // reset pause flag if necessary
            if shouldPauseTracking {
                shouldPauseTracking = false
            }
            
            // perform drawing in next loop
            if !enableGPUAcceleration {
                setNeedsDisplay(bounds)
            } else {
                
                // calculate size for single grid
                let gridSize = CGSize(
                    width: wrappedRenderingArea.width / CGFloat(wrappedPixelRect.width),
                    height: wrappedRenderingArea.height / CGFloat(wrappedPixelRect.height)
                )
                
                if  backingLayer.path != nil,
                    let backingGridSize = backingGridSize,
                    (
                        SceneGridView.minimumScaleOfRasterization...SceneGridView.maximumScaleOfRasterization ~= (gridSize.width / backingGridSize.width)
                        && SceneGridView.minimumScaleOfRasterization...SceneGridView.maximumScaleOfRasterization ~= (gridSize.height / backingGridSize.height)
                    ),
                    let backingPixelSize = backingPixelSize, (wrappedPixelRect.width <= backingPixelSize.width && wrappedPixelRect.height <= backingPixelSize.height)
                {
                    
                    backingLayer.setAffineTransform(
                        CGAffineTransform(
                            translationX: rect.minX <= 0.0 ? wrappedRenderingArea.minX : wrappedRenderingArea.maxX - gridSize.width * CGFloat(backingPixelSize.width),
                            y: rect.minY <= 0.0 ? wrappedRenderingArea.minY : wrappedRenderingArea.maxY - gridSize.height * CGFloat(backingPixelSize.height)
                        ).scaledBy(
                            x: gridSize.width / backingGridSize.width,
                            y: gridSize.height / backingGridSize.height
                        )
                    )
                    
                }
                else
                {
                    
                    let pixelSize = PixelSize(
                        width: wrappedPixelRect.width + max(Int(SceneGridView.defaultCachedSquareSize.width / gridSize.width), 1),
                        height: wrappedPixelRect.height + max(Int(SceneGridView.defaultCachedSquareSize.height / gridSize.height), 1)
                    )
                    debugPrint("update cached square: \(pixelSize)")
                    
                    let maxX = CGFloat(pixelSize.width) * gridSize.width
                    let maxY = CGFloat(pixelSize.height) * gridSize.height
                    let shapePath = CGMutablePath()
                    for x in 1 ..< pixelSize.width {
                        let xPos = CGFloat(x) * gridSize.width
                        shapePath.move(to: CGPoint(x: xPos, y: 0.0))
                        shapePath.addLine(to: CGPoint(x: xPos, y: maxY))
                    }
                    for y in 1 ..< pixelSize.height {
                        let yPos = CGFloat(y) * gridSize.height
                        shapePath.move(to: CGPoint(x: 0.0, y: yPos))
                        shapePath.addLine(to: CGPoint(x: maxX, y: yPos))
                    }
                    
                    backingLayer.path = shapePath
                    
                    backingGridSize = gridSize
                    backingPixelSize = pixelSize
                    
                    backingLayer.setAffineTransform(
                        CGAffineTransform(
                            translationX: rect.minX <= 0.0 ? wrappedRenderingArea.minX : wrappedRenderingArea.maxX - gridSize.width * CGFloat(pixelSize.width),
                            y: rect.minY <= 0.0 ? wrappedRenderingArea.minY : wrappedRenderingArea.maxY - gridSize.height * CGFloat(pixelSize.height)
                        )
                    )
                    
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
                    
                    debugPrint("cleared cached square")
                }
            }
            
            // store unused values
            storedSceneView = sceneView
            storedRect = rect
            storedMagnification = magnification
            
        }
        
    }
    
}
