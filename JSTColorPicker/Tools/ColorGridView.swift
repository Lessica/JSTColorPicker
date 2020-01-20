//
//  ColorGridView.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/20/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class ColorGridView: NSView {
    
    var image: PixelImage? {
        didSet {
            if let size = image?.pixelImageRep.size() {
                imageSize = size
            }
        }
    }
    var imageSize: CGSize = CGSize.zero
    var centerPoint: CGPoint = CGPoint.zero {
        didSet {
            setNeedsDisplay(bounds)
        }
    }
    var animating: Bool = false {
        didSet {
            if animating {
                shimAnimation(false)
            }
        }
    }
    fileprivate var pixelSize = CGSize(width: 24.0, height: 24.0)
    fileprivate var hPixelNum: Int = 0
    fileprivate var vPixelNum: Int = 0
    fileprivate lazy var centerMaskView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = .white
        return view
    }()
    
    fileprivate func shimAnimation(_ opaque: Bool) {
        if !animating { return }
        NSAnimationContext.runAnimationGroup({ [weak self] (context) in
            guard let self = self else { return }
            context.duration = 0.6
            self.centerMaskView.animator().alphaValue = opaque ? 1.0 : 0.0
        }) {
            self.shimAnimation(!opaque)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        hPixelNum = Int(bounds.width / pixelSize.width)
        vPixelNum = Int(bounds.height / pixelSize.height)
        centerMaskView.frame = CGRect(x: CGFloat(hPixelNum / 2 * Int(pixelSize.width)), y: CGFloat(vPixelNum / 2 * Int(pixelSize.height)), width: pixelSize.width, height: pixelSize.height)
        addSubview(centerMaskView)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.setLineCap(.square)
            ctx.setLineWidth(1)
            
            let hNum = CGFloat(hPixelNum) / 2.0
            let vNum = CGFloat(vPixelNum) / 2.0
            
            let p = centerPoint
            let s = pixelSize
            let m = imageSize
            
            for i in 0..<Int(hNum * 2) {
                for j in 0..<Int(vNum * 2) {
                    let t = CGPoint(x: Int(p.x) - Int(hNum) + i, y: Int(p.y) + Int(vNum) - j)
                    if t.x < 0 || t.y < 0 || t.x > m.width || t.y > m.height {
                        ctx.setFillColor(.clear)
                        ctx.setStrokeColor(.clear)
                    } else {
                        if let c = image?.pixelImageRep.getJSTColor(of: t) {
                            ctx.setFillColor(c.getNSColor().cgColor)
                        } else {
                            ctx.setFillColor(.clear)
                        }
                        if t.equalTo(p) {
                            ctx.setStrokeColor(.black)
                        } else {
                            ctx.setStrokeColor(.white)
                        }
                    }
                    ctx.addRect(CGRect(x: CGFloat(i) * s.width, y: CGFloat(j) * s.height, width: s.width, height: s.height))
                    ctx.drawPath(using: .fillStroke)
                }
            }
        }
        
    }
    
}
