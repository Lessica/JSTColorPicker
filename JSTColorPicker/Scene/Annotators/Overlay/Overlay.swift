//
//  OverlayView.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/10/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa


// MARK: - Structs

struct OverlayAnimationState {
    var lineDashCount: Int = 0
}

struct OverlayAnimationProxy: Hashable {
    weak var overlay: Overlay?
}


// MARK: - Implementation

class Overlay: NSView {
    
    
    // MARK: - Attributes

    enum BorderStyle {
        case none
        case solid
        case dashed
    }
    
    var borderStyle      : BorderStyle  { .none }
    var isFocused        : Bool         = false
    var isSelected       : Bool         = false
    {
        didSet {
            if isSelected {
                animationState.lineDashCount %= 9
                addToAnimationGroup()
            } else {
                removeFromAnimationGroup()
            }
        }
    }
    
    private var _isHighlighted: Bool         = false
    var isHighlighted: Bool
    {
        get {
            isFocused ? true : _isHighlighted
        }
        set {
            _isHighlighted = newValue
        }
    }
    
    var outerInsets: NSEdgeInsets { Overlay.defaultOuterInsets }
    var innerInsets: NSEdgeInsets { Overlay.defaultInnerInsets }
    
    
    // MARK: - Styles
    
    var animationState                                  = OverlayAnimationState()
    var animationBeginPhase                             : CGFloat { CGFloat(animationState.lineDashCount % 9) }
    
    private static let defaultBorderWidth               :  CGFloat  = 1.67
    private static let defaultLineDashLengths           : [CGFloat] = [5.0, 4.0]  // (performance) only two items are allowed
    
    var lineDashColorsNormal                            : [CGColor]?
    var lineDashColorsHighlighted                       : [CGColor]?
    private var internalLineDashColorsNormal            : [CGColor] { lineDashColorsNormal ?? Overlay.defaultLineDashColorsNormal }
    private var internalLineDashColorsHighlighted       : [CGColor] { lineDashColorsHighlighted ?? Overlay.defaultLineDashColorsHighlighted }
    private static var defaultLineDashColorsNormal      : [CGColor] { [NSColor.white.cgColor, NSColor.black.cgColor] }
    private static var defaultLineDashColorsHighlighted : [CGColor] { [NSColor.white.cgColor, NSColor.controlAccentColor.cgColor] }
    
    var capturedImage: NSImage? {
        guard let rep = bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
        cacheDisplay(in: bounds, to: rep)
        let img = NSImage(size: bounds.size)
        img.addRepresentation(rep)
        return img
    }
    
    private static let defaultOuterInsets = NSEdgeInsets(
        top: -defaultBorderWidth,
        left: -defaultBorderWidth,
        bottom: -defaultBorderWidth,
        right: -defaultBorderWidth
    )
    
    private static let defaultInnerInsets = NSEdgeInsets(
        top: defaultBorderWidth,
        left: defaultBorderWidth,
        bottom: defaultBorderWidth,
        right: defaultBorderWidth
    )
    
    
    // MARK: - Animation

    private static var sharedAnimationTimer: Timer?
    private static func installSharedAnimationTimer() {
        if let oldTimer = sharedAnimationTimer {
            oldTimer.invalidate()
            sharedAnimationTimer = nil
        }
        let timer = Timer(fireAt: Date(), interval: 0.1, target: self, selector: #selector(sharedAnimateAction(_:)), userInfo: nil, repeats: true)
        RunLoop.current.add(timer, forMode: .common)
        sharedAnimationTimer = timer
        //debugPrint("\(className()):\(#function)")
    }
    private static func invalidateSharedAnimationTimer() {
        sharedAnimationTimer?.invalidate()
        sharedAnimationTimer = nil
        //debugPrint("\(className()):\(#function)")
    }
    private static var sharedAnimationProxies = Set<OverlayAnimationProxy>()
    @objc static func sharedAnimateAction(_ timer: Timer) {
        sharedAnimationProxies
            .compactMap({ $0.overlay })
            .forEach({ $0.animateAction(timer) })
        //debugPrint("\(className()):\(#function)")
    }
    
    private func animateAction(_ timer: Timer) {
        if shouldPerformAnimatableDrawing {
            animationState.lineDashCount += 1
            setNeedsDisplay(visibleOnly: true)
        }
    }
    
    func addToAnimationGroup() {
        Overlay.sharedAnimationProxies.insert(OverlayAnimationProxy(overlay: self))
        if Overlay.sharedAnimationTimer == nil && !Overlay.sharedAnimationProxies.isEmpty {
            Overlay.installSharedAnimationTimer()
        }
    }
    
    func removeFromAnimationGroup() {
        let proxies = Overlay.sharedAnimationProxies
            .filter({ $0.overlay == nil || $0.overlay == self })
        Overlay.sharedAnimationProxies.subtract(proxies)  // mutating
        if Overlay.sharedAnimationTimer != nil && Overlay.sharedAnimationProxies.isEmpty {
            Overlay.invalidateSharedAnimationTimer()
        }
    }
    
    
    // MARK: - Initializers
    
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
    
    deinit {
        removeFromAnimationGroup()
    }
    
    
    // MARK: - Drawing
    
    override var wantsDefaultClipping: Bool { false }
    
    func setNeedsDisplay(visibleOnly: Bool) {
        if visibleOnly {
            super.setNeedsDisplay(visibleRect)
        } else {
            super.setNeedsDisplay(bounds)
        }
    }
    
    private var shouldPerformAnimatableDrawing: Bool {
        return (!isHidden && borderStyle == .dashed) ? shouldPerformDrawing(visibleRect, bounds.inset(by: innerInsets)) : false
    }
    
    private func shouldPerformDrawing(_ dirtyRect: CGRect, _ drawBounds: CGRect) -> Bool {
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
        guard borderStyle != .none else { return }
        
        let drawBounds = bounds.inset(by: innerInsets)
        guard shouldPerformDrawing(dirtyRect, drawBounds) else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
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
        
        ctx.setLineCap(.round)
        ctx.setLineWidth(Overlay.defaultBorderWidth)
        if isFocused || isHighlighted || isSelected { ctx.setStrokeColor(internalLineDashColorsHighlighted[1]) }
        else { ctx.setStrokeColor(internalLineDashColorsNormal[1]) }
        ctx.strokePath()
        
        if borderStyle == .dashed {
            
            let drawLength = Overlay.defaultLineDashLengths[0], spaceLength = Overlay.defaultLineDashLengths[1]
            let mixedLength = drawLength + spaceLength
            
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
            
            ctx.setLineCap(.butt)
            ctx.setLineWidth(Overlay.defaultBorderWidth)
            if isFocused || isHighlighted || isSelected { ctx.setStrokeColor(internalLineDashColorsHighlighted[0]) }
            else { ctx.setStrokeColor(internalLineDashColorsNormal[0]) }
            ctx.strokePath()
            
        }
        
        ctx.restoreGState()
    }
    
}

