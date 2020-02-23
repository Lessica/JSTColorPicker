//
//  OverlayView.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/10/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

class Overlay: NSView {
    
    static let borderWidth: CGFloat = 1.0
    
    var lineDashCount: Int = 0
    var lineDashBeginPhase: CGFloat {
        return CGFloat(8 - lineDashCount % 9)
    }
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
        setNeedsDisplay(bounds)
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
    
    override func draw(_ dirtyRect: NSRect) {
        guard isBordered else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        // black-white painted dashed lines
        
        let drawBounds = bounds.inset(by: innerInsets)
        guard !drawBounds.isNull else { return }
        
        ctx.saveGState()
        
        ctx.setLineWidth(Overlay.borderWidth)
        ctx.setStrokeColor(.black)
        ctx.stroke(drawBounds)
        
        ctx.setLineDash(phase: lineDashBeginPhase, lengths: [5.0, 4.0])
        ctx.setStrokeColor(.white)
        
        ctx.move(to: CGPoint(x: drawBounds.minX, y: drawBounds.minY))
        ctx.addLine(to: CGPoint(x: drawBounds.maxX, y: drawBounds.minY))
        ctx.strokePath()
        
        ctx.move(to: CGPoint(x: drawBounds.maxX, y: drawBounds.maxY))
        ctx.addLine(to: CGPoint(x: drawBounds.maxX, y: drawBounds.minY))
        ctx.strokePath()
        
        ctx.move(to: CGPoint(x: drawBounds.minX, y: drawBounds.maxY))
        ctx.addLine(to: CGPoint(x: drawBounds.maxX, y: drawBounds.maxY))
        ctx.strokePath()
        
        ctx.move(to: CGPoint(x: drawBounds.minX, y: drawBounds.maxY))
        ctx.addLine(to: CGPoint(x: drawBounds.minX, y: drawBounds.minY))
        ctx.strokePath()
        
        ctx.restoreGState()
    }
    
}
