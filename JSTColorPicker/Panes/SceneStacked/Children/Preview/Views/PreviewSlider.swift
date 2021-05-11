//
//  PreviewSlider.swift
//  JSTColorPicker
//
//  Created by Rachel on 5/10/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class PreviewSlider: NSSlider {
    
    private var _cachedMaximumSmartMagnification  : CGFloat = 0
    
    override func awakeFromNib() {
        super.awakeFromNib()
        resetMaximumSmartMagnification()
    }
    
    func resetMaximumSmartMagnification() {
        _cachedMaximumSmartMagnification = UserDefaults.standard[.sceneMaximumSmartMagnification]
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.saveGState()
            
            let minValue = minValue
            let maxValue = maxValue
            let cachedFirstTickMarkBounds = rectOfTickMark(at: 0)
            let cachedLastTickMarkBounds  = rectOfTickMark(at: numberOfTickMarks - 1)
            let knobThickness             = knobThickness
            let beginLocation             = cachedFirstTickMarkBounds.minX + knobThickness / 2 - cachedFirstTickMarkBounds.width / 2 - 1
            let endLocation               = cachedLastTickMarkBounds.maxX - knobThickness / 2 + cachedLastTickMarkBounds.width / 2 + 1
            let markWidth                 = cachedFirstTickMarkBounds.width * 2
            
            let drawDot: (Double, CGColor) -> Void = { (value, color) in
                if value >= minValue && value <= maxValue
                {
                    let ratio = (value - minValue) / (maxValue - minValue)
                    let centerX = ratio * Double(endLocation - beginLocation)
                    let markRect = CGRect(
                        x: beginLocation + CGFloat(centerX) - markWidth / 2,
                        y: cachedFirstTickMarkBounds.maxY - 2.0,
                        width: markWidth,
                        height: markWidth
                    )
                    
                    ctx.setFillColor(color)
                    ctx.addEllipse(in: markRect)
                    ctx.fillPath()
                }
            }
            
            drawDot(0, NSColor.separatorColor.withAlphaComponent(0.5).cgColor)
            drawDot(log2(Double(_cachedMaximumSmartMagnification)), NSColor.controlAccentColor.withAlphaComponent(0.75).cgColor)
            ctx.restoreGState()
        }
        
        
        super.draw(dirtyRect)
    }
    
}
