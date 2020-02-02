//
//  ColorGridView.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/20/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class ColorGridView: NSView {
    
    weak var dataSource: ScreenshotLoader?
    var centerCoordinate: PixelCoordinate = PixelCoordinate() {
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
    fileprivate var pixelSize = CGSize(width: 14.0, height: 14.0)
    fileprivate var hPixelNum: Int = 0
    fileprivate var vPixelNum: Int = 0
    fileprivate lazy var centerMaskView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = .white
        return view
    }()
    fileprivate var pixelImage: JSTPixelImage? {
        return dataSource?.screenshot?.image?.pixelImageRep
    }
    fileprivate static let gridLineColor = NSColor.textBackgroundColor
    fileprivate static let gridCenterLineColor = NSColor.textColor
    
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
        
        guard let pixelImage = pixelImage else { return }
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.setLineCap(.square)
            ctx.setLineWidth(1)
            
            let hNum = CGFloat(hPixelNum) / 2.0
            let vNum = CGFloat(vPixelNum) / 2.0
            var centralPoints: [(PixelCoordinate, CGRect)] = []
            let imageSize = pixelImage.size()
            
            for i in 0..<Int(hNum * 2) {
                for j in 0..<Int(vNum * 2) {
                    let coord = PixelCoordinate(x: centerCoordinate.x - Int(hNum) + i, y: centerCoordinate.y + Int(vNum) - j)
                    if coord.x > 0 && coord.y > 0 && coord.x < Int(floor(imageSize.width)) && coord.y < Int(floor(imageSize.height)) {
                        let rect = CGRect(x: CGFloat(i) * pixelSize.width, y: CGFloat(j) * pixelSize.height, width: pixelSize.width, height: pixelSize.height)
                        if centerCoordinate != coord {
                            ctx.setFillColor(pixelImage.getJSTColor(of: coord.toCGPoint()).toNSColor().cgColor)
                            ctx.setStrokeColor(ColorGridView.gridLineColor.cgColor)
                            ctx.addRect(rect)
                            ctx.drawPath(using: .fillStroke)
                        } else {
                            centralPoints.append((coord, rect))
                        }
                    }
                }
            }
            
            for (coord, rect) in centralPoints {
                ctx.setFillColor(pixelImage.getJSTColor(of: coord.toCGPoint()).toNSColor().cgColor)
                ctx.setStrokeColor(ColorGridView.gridCenterLineColor.cgColor)
                ctx.addRect(rect)
                ctx.drawPath(using: .fillStroke)
            }
        }
        
    }
    
}
