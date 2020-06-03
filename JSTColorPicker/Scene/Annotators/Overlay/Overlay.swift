//
//  OverlayView.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/10/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

struct OverlayAnimationState {
    public var lineDashCount: Int = 0
}

class Overlay: NSView {
    
    public var isFocused: Bool = false
    public var isBordered: Bool {
        return false
    }
    
    public var outerInsets: NSEdgeInsets {
        return Overlay.defaultOuterInsets
    }
    
    public var innerInsets: NSEdgeInsets {
        return Overlay.defaultInnerInsets
    }
    
    public var capturedImage: NSImage? {
        guard let rep = bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
        cacheDisplay(in: bounds, to: rep)
        let img = NSImage(size: bounds.size)
        img.addRepresentation(rep)
        return img
    }
    
    public func invalidateAnimationTimer() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    public var animationState = OverlayAnimationState()
    public var animationBeginPhase: CGFloat { CGFloat(animationState.lineDashCount % 9) }
    fileprivate var animationTimer: Timer?
    
    fileprivate static let defaultBorderWidth    :  CGFloat  = 1.67
    fileprivate static let defaultLineDashLengths: [CGFloat] = [5.0, 4.0]  // (performance) only two items allowed
    
    public var lineDashColorsNormal                        : [CGColor]?
    public var lineDashColorsHighlighted                   : [CGColor]?
    fileprivate var internalLineDashColorsNormal           : [CGColor] { lineDashColorsNormal ?? Overlay.defaultLineDashColorsNormal }
    fileprivate var internalLineDashColorsHighlighted      : [CGColor] { lineDashColorsHighlighted ?? Overlay.defaultLineDashColorsHighlighted }
    fileprivate static let defaultLineDashColorsNormal     : [CGColor] = [NSColor.white.cgColor, NSColor.black.cgColor]
    fileprivate static let defaultLineDashColorsHighlighted: [CGColor] = [NSColor.white.cgColor, NSColor.systemBlue.cgColor]
    
    fileprivate static let defaultOuterInsets = NSEdgeInsets(top: -defaultBorderWidth, left: -defaultBorderWidth, bottom: -defaultBorderWidth, right: -defaultBorderWidth)
    fileprivate static let defaultInnerInsets = NSEdgeInsets(top: defaultBorderWidth, left: defaultBorderWidth, bottom: defaultBorderWidth, right: defaultBorderWidth)
    
    public var isSelected: Bool = false {
        didSet {
            //guard isBordered else { return }
            if isSelected {
                invalidateAnimationTimer()
                animationState.lineDashCount %= 9
                let timer = Timer(fireAt: Date(), interval: 0.1, target: self, selector: #selector(animateLineDash(_:)), userInfo: nil, repeats: true)
                RunLoop.current.add(timer, forMode: .common)
                animationTimer = timer
            } else {
                invalidateAnimationTimer()
            }
        }
    }
    
    deinit {
        invalidateAnimationTimer()
    }
    
    @objc internal func animateLineDash(_ timer: Timer?) {
        if shouldPerformAnimatableDrawing {
            animationState.lineDashCount += 1
            setNeedsDisplay(visibleOnly: true)
        }
    }
    
    public func setNeedsDisplay(visibleOnly: Bool) {
        if visibleOnly {
            super.setNeedsDisplay(visibleRect)
        } else {
            super.setNeedsDisplay(bounds)
        }
    }
    
    override var wantsDefaultClipping: Bool { false }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        wantsLayer = true
        canDrawSubviewsIntoLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layerContentsPlacement = .center
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard frame.contains(point) else { return nil }
        return self
    }
    
    fileprivate var shouldPerformAnimatableDrawing: Bool {
        return (!isHidden && isBordered) ? shouldPerformDrawing(visibleRect, bounds.inset(by: innerInsets)) : false
    }
    
    fileprivate func shouldPerformDrawing(_ dirtyRect: CGRect, _ drawBounds: CGRect) -> Bool {
        guard !drawBounds.isEmpty else { return false }
        guard (
            (drawBounds.minY > dirtyRect.minY && drawBounds.minY < dirtyRect.maxY) ||
            (drawBounds.maxX > dirtyRect.minX && drawBounds.maxX < dirtyRect.maxX) ||
            (drawBounds.maxY > dirtyRect.minY && drawBounds.maxY < dirtyRect.maxY) ||
            (drawBounds.minX > dirtyRect.minX && drawBounds.minX < dirtyRect.maxX)
        ) else { return false }
        return true
    }
    
    // black-white painted dashed lines, draw only inside dirtyRect to improve performance
    override func draw(_ dirtyRect: NSRect) {
        //guard !inLiveResize else { return }
        guard isBordered else { return }
        
        let drawBounds = bounds.inset(by: innerInsets)
        guard shouldPerformDrawing(dirtyRect, drawBounds) else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        let drawLength = Overlay.defaultLineDashLengths[0], spaceLength = Overlay.defaultLineDashLengths[1]
        let mixedLength = drawLength + spaceLength
        
        ctx.saveGState()
        
        if drawBounds.minY > dirtyRect.minY && drawBounds.minY < dirtyRect.maxY {
            ctx.move(to: CGPoint(x: max(dirtyRect.minX, drawBounds.minX), y: drawBounds.minY))
            ctx.addLine(to: CGPoint(x: min(dirtyRect.maxX, drawBounds.maxX), y: drawBounds.minY))
        }
        if drawBounds.maxX > dirtyRect.minX && drawBounds.maxX < dirtyRect.maxX {
            ctx.move(to: CGPoint(x: drawBounds.maxX, y: min(dirtyRect.maxY, drawBounds.maxY)))
            ctx.addLine(to: CGPoint(x: drawBounds.maxX, y: max(dirtyRect.minY, drawBounds.minY)))
        }
        if drawBounds.maxY > dirtyRect.minY && drawBounds.maxY < dirtyRect.maxY {
            ctx.move(to: CGPoint(x: max(dirtyRect.minX, drawBounds.minX), y: drawBounds.maxY))
            ctx.addLine(to: CGPoint(x: min(dirtyRect.maxX, drawBounds.maxX), y: drawBounds.maxY))
        }
        if drawBounds.minX > dirtyRect.minX && drawBounds.minX < dirtyRect.maxX {
            ctx.move(to: CGPoint(x: drawBounds.minX, y: min(dirtyRect.maxY, drawBounds.maxY)))
            ctx.addLine(to: CGPoint(x: drawBounds.minX, y: max(dirtyRect.minY, drawBounds.minY)))
        }
        ctx.setLineWidth(Overlay.defaultBorderWidth)
        if isFocused || isSelected { ctx.setStrokeColor(internalLineDashColorsHighlighted[1]) }
        else { ctx.setStrokeColor(internalLineDashColorsNormal[1]) }
        ctx.strokePath()
        
        if drawBounds.minY > dirtyRect.minY && drawBounds.minY < dirtyRect.maxY {
            let xLower = max(dirtyRect.minX, drawBounds.minX)
            let xUpper = min(dirtyRect.maxX, drawBounds.maxX)
            let beginX = drawBounds.minX + animationBeginPhase
            let deltaX = xLower - (floor((xLower - beginX) / (mixedLength)) * mixedLength) - beginX
            var drawX: CGFloat
            if deltaX < drawLength {
                let remainLength = drawLength - deltaX
                drawX = xLower
                ctx.move(to: CGPoint(x: drawX, y: drawBounds.minY))
                drawX += min(remainLength, xUpper - drawX)
                ctx.addLine(to: CGPoint(x: drawX, y: drawBounds.minY))
                drawX += spaceLength
            }
            else {
                let remainLength = mixedLength - deltaX
                drawX = xLower + remainLength
            }
            while drawX < xUpper {
                ctx.move(to: CGPoint(x: drawX, y: drawBounds.minY))
                drawX += min(drawLength, xUpper - drawX)
                ctx.addLine(to: CGPoint(x: drawX, y: drawBounds.minY))
                drawX += spaceLength
            }
        }
        if drawBounds.maxX > dirtyRect.minX && drawBounds.maxX < dirtyRect.maxX {
            let yUpper = min(dirtyRect.maxY, drawBounds.maxY)
            let yLower = max(dirtyRect.minY, drawBounds.minY)
            let beginY = drawBounds.maxY - animationBeginPhase
            let deltaY = beginY - (yUpper + (floor((beginY - yUpper) / (mixedLength)) * mixedLength))
            var drawY: CGFloat
            if deltaY < drawLength {
                let remainLength = drawLength - deltaY
                drawY = yUpper
                ctx.move(to: CGPoint(x: drawBounds.maxX, y: drawY))
                drawY -= min(remainLength, drawY - yLower)
                ctx.addLine(to: CGPoint(x: drawBounds.maxX, y: drawY))
                drawY -= spaceLength
            }
            else {
                let remainLength = mixedLength - deltaY
                drawY = yUpper - remainLength
            }
            while drawY > yLower {
                ctx.move(to: CGPoint(x: drawBounds.maxX, y: drawY))
                drawY -= min(drawLength, drawY - yLower)
                ctx.addLine(to: CGPoint(x: drawBounds.maxX, y: drawY))
                drawY -= spaceLength
            }
        }
        if drawBounds.maxY > dirtyRect.minY && drawBounds.maxY < dirtyRect.maxY {
            let xLower = max(dirtyRect.minX, drawBounds.minX)
            let xUpper = min(dirtyRect.maxX, drawBounds.maxX)
            let beginX = drawBounds.minX + animationBeginPhase
            let deltaX = xLower - (floor((xLower - beginX) / (mixedLength)) * mixedLength) - beginX
            var drawX: CGFloat
            if deltaX < drawLength {
                let remainLength = drawLength - deltaX
                drawX = xLower
                ctx.move(to: CGPoint(x: drawX, y: drawBounds.maxY))
                drawX += min(remainLength, xUpper - drawX)
                ctx.addLine(to: CGPoint(x: drawX, y: drawBounds.maxY))
                drawX += spaceLength
            }
            else {
                let remainLength = mixedLength - deltaX
                drawX = xLower + remainLength
            }
            while drawX < xUpper {
                ctx.move(to: CGPoint(x: drawX, y: drawBounds.maxY))
                drawX += min(drawLength, xUpper - drawX)
                ctx.addLine(to: CGPoint(x: drawX, y: drawBounds.maxY))
                drawX += spaceLength
            }
        }
        if drawBounds.minX > dirtyRect.minX && drawBounds.minX < dirtyRect.maxX {
            let yUpper = min(dirtyRect.maxY, drawBounds.maxY)
            let yLower = max(dirtyRect.minY, drawBounds.minY)
            let beginY = drawBounds.maxY - animationBeginPhase
            let deltaY = beginY - (yUpper + (floor((beginY - yUpper) / (mixedLength)) * mixedLength))
            var drawY: CGFloat
            if deltaY < drawLength {
                let remainLength = drawLength - deltaY
                drawY = yUpper
                ctx.move(to: CGPoint(x: drawBounds.minX, y: drawY))
                drawY -= min(remainLength, drawY - yLower)
                ctx.addLine(to: CGPoint(x: drawBounds.minX, y: drawY))
                drawY -= spaceLength
            }
            else {
                let remainLength = mixedLength - deltaY
                drawY = yUpper - remainLength
            }
            while drawY > yLower {
                ctx.move(to: CGPoint(x: drawBounds.minX, y: drawY))
                drawY -= min(drawLength, drawY - yLower)
                ctx.addLine(to: CGPoint(x: drawBounds.minX, y: drawY))
                drawY -= spaceLength
            }
        }
        
        // ctx.setLineWidth(Overlay.defaultBorderWidth)
        if isFocused || isSelected { ctx.setStrokeColor(internalLineDashColorsHighlighted[0]) }
        else { ctx.setStrokeColor(internalLineDashColorsNormal[0]) }
        ctx.strokePath()
        
        ctx.restoreGState()
    }
    
}
