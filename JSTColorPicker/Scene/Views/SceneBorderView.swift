//
//  SceneBorderView.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/1/4.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class SceneBorderView: NSView {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = true
        
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layerContentsPlacement = .center
        if let compositingFilter = CIFilter(name: "CIOverlayBlendMode") {
            layer?.compositingFilter = compositingFilter
        }
    }
    
    override var isFlipped: Bool { true }
    override var wantsDefaultClipping: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }  // disable user interactions
    override func cursorUpdate(with event: NSEvent) { }  // do not perform default behavior
    
    public var drawBordersInScene: Bool = false
    
    private static let defaultBorderLineWidth         : CGFloat = 2.0
    private static let defaultBorderLineColor         = CGColor(gray: 1.0, alpha: 1.0)
    
    private var wrappedRenderingArea: CGRect = .null
    private var positionSatisfiedGridDrawing: Bool {
        !wrappedRenderingArea.isEmpty
        && wrappedRenderingArea.width > 1e-3
        && wrappedRenderingArea.height > 1e-3
        &&
        (
            abs(wrappedRenderingArea.minX.distance(to: bounds.minX)) > 1e-3
            || abs(wrappedRenderingArea.minY.distance(to: bounds.minY)) > 1e-3
            || abs(wrappedRenderingArea.maxX.distance(to: bounds.maxX)) > 1e-3
            || abs(wrappedRenderingArea.maxY.distance(to: bounds.maxY)) > 1e-3
        )
    }
    
    // MARK: - CPU Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        
        guard !inLiveResize
            && drawBordersInScene
            && positionSatisfiedGridDrawing
            && !isHidden
            else
        {
            //debugPrint("cleared \(className):\(#function)")
            return
        }
        
        //debugPrint("painted \(className):\(#function)")
        
        // got context
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setShouldAntialias(true)
        ctx.setLineWidth(SceneBorderView.defaultBorderLineWidth)
        ctx.setStrokeColor(SceneBorderView.defaultBorderLineColor)
        
        // draw border flawlessly
        if abs(wrappedRenderingArea.minX.distance(to: bounds.minX)) > 1e-3 {
            ctx.move(to: wrappedRenderingArea.pointMinXMinY)
            ctx.addLine(to: wrappedRenderingArea.pointMinXMaxY)
        }
        if abs(wrappedRenderingArea.minY.distance(to: bounds.minY)) > 1e-3 {
            ctx.move(to: wrappedRenderingArea.pointMinXMinY)
            ctx.addLine(to: wrappedRenderingArea.pointMaxXMinY)
        }
        if abs(wrappedRenderingArea.maxX.distance(to: bounds.maxX)) > 1e-3 {
            ctx.move(to: wrappedRenderingArea.pointMaxXMinY)
            ctx.addLine(to: wrappedRenderingArea.pointMaxXMaxY)
        }
        if abs(wrappedRenderingArea.maxY.distance(to: bounds.maxY)) > 1e-3 {
            ctx.move(to: wrappedRenderingArea.pointMinXMaxY)
            ctx.addLine(to: wrappedRenderingArea.pointMaxXMaxY)
        }
        
        ctx.strokePath()
        
    }
    
    
    // MARK: - Live Resize
    
    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
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
                    sceneVisibleRectDidChange(storedSceneView, to: rect, of: magnification)
                }
                
            } else {
                
                storedSceneView = nil
                storedRect = nil
                storedMagnification = nil
                
            }
        }
    }
    
}

extension SceneBorderView: SceneTracking {
    
    func sceneVisibleRectDidChange(_ sender: SceneScrollView?, to rect: CGRect, of magnification: CGFloat) {
        
        guard let sceneView = sender else { return }
        
        var drawable: Bool = drawBordersInScene && !isHidden
        
        if drawable {
            // update draw areas, and positions
            let wrappedRestrictedRect = rect.intersection(sceneView.wrapperBounds)
            if !rect.isEmpty && !wrappedRestrictedRect.isEmpty {
                wrappedRenderingArea = sceneView
                    .convertFromDocumentView(wrappedRestrictedRect)
                    .offsetBy(-sceneView.alternativeBoundsOrigin)
                    .intersection(bounds)
                drawable = positionSatisfiedGridDrawing
            } else {
                wrappedRenderingArea = .null
                drawable = false
            }
        }
        
        if drawable {
            
            // reset pause flag if necessary
            if shouldPauseTracking {
                shouldPauseTracking = false
            }
            
            setNeedsDisplay(bounds)
            
        }
        else {
            
            // clear current core graphics context if necessary
            if !shouldPauseTracking {
                shouldPauseTracking = true
                
                setNeedsDisplay(bounds)
            }
            
            // store unused values
            storedSceneView = sceneView
            storedRect = rect
            storedMagnification = magnification
            
        }
        
    }
    
}
