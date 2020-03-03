//
//  OverlayView.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/10/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

extension NSView {
    
    func setNeedsDisplay() {
        setNeedsDisplay(bounds)
    }
    
}

class Overlay: NSView {
    
    static let borderWidth: CGFloat = 1.0
    
    var lineDashCount: Int = 0
    var lineDashBeginPhase: CGFloat {
        return CGFloat(lineDashCount % 9)
    }
    var lineDashLengths: [CGFloat] = [5.0, 4.0]
    fileprivate var lineDashTimer: Timer?
    
    var isAnimating: Bool = false {
        didSet {
            if isAnimating {
                lineDashCount = lineDashCount % 9
                let timer = Timer(fireAt: Date(), interval: 0.1, target: self, selector: #selector(animateLineDash(_:)), userInfo: nil, repeats: true)
                RunLoop.current.add(timer, forMode: .common)
                lineDashTimer = timer
            } else {
                lineDashTimer?.invalidate()
            }
        }
    }
    
    deinit {
        lineDashTimer?.invalidate()
    }
    
    @objc internal func animateLineDash(_ timer: Timer?) {
        lineDashCount += 1
        setNeedsDisplay()
    }
    
    var isBordered: Bool {
        return false
    }
    
    var outerInsets: NSEdgeInsets {
        return NSEdgeInsets(top: -Overlay.borderWidth, left: -Overlay.borderWidth, bottom: -Overlay.borderWidth, right: -Overlay.borderWidth)
    }
    
    var innerInsets: NSEdgeInsets {
        return NSEdgeInsets(top: Overlay.borderWidth, left: Overlay.borderWidth, bottom: Overlay.borderWidth, right: Overlay.borderWidth)
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        wantsLayer = true
        canDrawSubviewsIntoLayer = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard isBordered else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        // black-white painted dashed lines
        
        let drawBounds = bounds.inset(by: innerInsets)
        guard !drawBounds.isNull else { return }
        
        let point0 = CGPoint(x: drawBounds.minX, y: drawBounds.minY)
        let point1 = CGPoint(x: drawBounds.maxX, y: drawBounds.minY)
        let point2 = CGPoint(x: drawBounds.maxX, y: drawBounds.maxY)
        let point3 = CGPoint(x: drawBounds.minX, y: drawBounds.maxY)
        
        ctx.saveGState()
        ctx.setLineWidth(Overlay.borderWidth)
        
        ctx.setStrokeColor(.black)
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
        
        ctx.strokePath()
        
        ctx.setStrokeColor(.white)
        
        var xLower: CGFloat, xUpper: CGFloat
        var yUpper: CGFloat, yLower: CGFloat
        let beginPhase = lineDashBeginPhase
        let drawLength = lineDashLengths[0], spaceLength = lineDashLengths[1]
        let mixedLength = drawLength + spaceLength
        
        if point0.y > dirtyRect.minY && point0.y < dirtyRect.maxY {
            xLower = max(dirtyRect.minX, point0.x)
            xUpper = min(dirtyRect.maxX, point1.x)
            let beginX = point0.x + beginPhase
            let deltaX = xLower - (floor((xLower - beginX) / (mixedLength)) * mixedLength) - beginX
            var drawX: CGFloat
            if deltaX < drawLength {
                let remainLength = drawLength - deltaX
                drawX = xLower
                ctx.move(to: CGPoint(x: drawX, y: point0.y))
                drawX += min(remainLength, xUpper - drawX)
                ctx.addLine(to: CGPoint(x: drawX, y: point0.y))
                drawX += spaceLength
            }
            else {
                let remainLength = mixedLength - deltaX
                drawX = xLower + remainLength
            }
            while drawX < xUpper {
                ctx.move(to: CGPoint(x: drawX, y: point0.y))
                drawX += min(drawLength, xUpper - drawX)
                ctx.addLine(to: CGPoint(x: drawX, y: point0.y))
                drawX += spaceLength
            }
        }
        if point2.x > dirtyRect.minX && point2.x < dirtyRect.maxX {
            yUpper = min(dirtyRect.maxY, point2.y)
            yLower = max(dirtyRect.minY, point1.y)
            let beginY = point2.y - beginPhase
            let deltaY = beginY - (yUpper + (floor((beginY - yUpper) / (mixedLength)) * mixedLength))
            var y: CGFloat
            if deltaY < drawLength {
                let remainLength = drawLength - deltaY
                y = yUpper
                ctx.move(to: CGPoint(x: point2.x, y: y))
                y -= min(remainLength, y - yLower)
                ctx.addLine(to: CGPoint(x: point2.x, y: y))
                y -= spaceLength
            }
            else {
                let remainLength = mixedLength - deltaY
                y = yUpper - remainLength
            }
            while y > yLower {
                ctx.move(to: CGPoint(x: point2.x, y: y))
                y -= min(drawLength, y - yLower)
                ctx.addLine(to: CGPoint(x: point2.x, y: y))
                y -= spaceLength
            }
        }
        if point3.y > dirtyRect.minY && point3.y < dirtyRect.maxY {
            xLower = max(dirtyRect.minX, point3.x)
            xUpper = min(dirtyRect.maxX, point2.x)
            let beginX = point3.x + beginPhase
            let deltaX = xLower - (floor((xLower - beginX) / (mixedLength)) * mixedLength) - beginX
            var drawX: CGFloat
            if deltaX < drawLength {
                let remainLength = drawLength - deltaX
                drawX = xLower
                ctx.move(to: CGPoint(x: drawX, y: point3.y))
                drawX += min(remainLength, xUpper - drawX)
                ctx.addLine(to: CGPoint(x: drawX, y: point3.y))
                drawX += spaceLength
            }
            else {
                let remainLength = mixedLength - deltaX
                drawX = xLower + remainLength
            }
            while drawX < xUpper {
                ctx.move(to: CGPoint(x: drawX, y: point3.y))
                drawX += min(drawLength, xUpper - drawX)
                ctx.addLine(to: CGPoint(x: drawX, y: point3.y))
                drawX += spaceLength
            }
        }
        if point3.x > dirtyRect.minX && point3.x < dirtyRect.maxX {
            yUpper = min(dirtyRect.maxY, point3.y)
            yLower = max(dirtyRect.minY, point0.y)
            let beginY = point3.y - beginPhase
            let deltaY = beginY - (yUpper + (floor((beginY - yUpper) / (mixedLength)) * mixedLength))
            var y: CGFloat
            if deltaY < drawLength {
                let remainLength = drawLength - deltaY
                y = yUpper
                ctx.move(to: CGPoint(x: point3.x, y: y))
                y -= min(remainLength, y - yLower)
                ctx.addLine(to: CGPoint(x: point3.x, y: y))
                y -= spaceLength
            }
            else {
                let remainLength = mixedLength - deltaY
                y = yUpper - remainLength
            }
            while y > yLower {
                ctx.move(to: CGPoint(x: point3.x, y: y))
                y -= min(drawLength, y - yLower)
                ctx.addLine(to: CGPoint(x: point3.x, y: y))
                y -= spaceLength
            }
        }
        
        ctx.strokePath()
        
        ctx.restoreGState()
    }
    
}
