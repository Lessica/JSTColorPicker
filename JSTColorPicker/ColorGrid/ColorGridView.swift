//
//  ColorGridView.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/20/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

enum GridState {
    case none
    case colorOccupied
    case areaOccupied
    case bothOccupied
    
    static let gridLineColor = NSColor.textBackgroundColor
    static let gridCenterLineColor = NSColor.textColor
    static let gridColorOccupiedLineColor = NSColor.red
    static let gridAreaOccupiedLineColor = NSColor.blue
    static let gridBothOccupiedLineColor = NSColor.red
    
    var color: NSColor {
        switch self {
        case .colorOccupied:
            return GridState.gridColorOccupiedLineColor
        case .areaOccupied:
            return GridState.gridAreaOccupiedLineColor
        case .bothOccupied:
            return GridState.gridBothOccupiedLineColor
        default:
            return GridState.gridLineColor
        }
    }
}

class ColorGridView: NSView {
    
    weak var dataSource: ScreenshotLoader?
    var centerCoordinate: PixelCoordinate = PixelCoordinate.zero {
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
    fileprivate lazy var centerOverlay: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = .white
        return view
    }()
    fileprivate var pixelImage: JSTPixelImage? {
        return dataSource?.screenshot?.image?.pixelImageRep
    }
    
    fileprivate func shimAnimation(_ opaque: Bool) {
        if !animating { return }
        NSAnimationContext.runAnimationGroup({ [weak self] (context) in
            guard let self = self else { return }
            context.duration = 0.6
            self.centerOverlay.animator().alphaValue = opaque ? 1.0 : 0.0
        }) {
            self.shimAnimation(!opaque)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        hPixelNum = Int(bounds.width / pixelSize.width)
        vPixelNum = Int(bounds.height / pixelSize.height)
        centerOverlay.frame = CGRect(x: CGFloat(hPixelNum / 2 * Int(pixelSize.width)), y: CGFloat(vPixelNum / 2 * Int(pixelSize.height)), width: pixelSize.width, height: pixelSize.height)
        addSubview(centerOverlay)
    }
    
    fileprivate func gridState(at coordinate: PixelCoordinate) -> GridState {
        guard let content = dataSource?.screenshot?.content else { return .none }
        let isOccupiedByColor = (content.colors.first(where: { $0.coordinate == coordinate }) != nil)
        let isOccupiedByArea  = (content.areas.first(where: { $0.rect.contains(coordinate) }) != nil)
        if isOccupiedByColor && isOccupiedByArea {
            return .bothOccupied
        }
        else if isOccupiedByColor {
            return .colorOccupied
        }
        else if isOccupiedByArea {
            return .areaOccupied
        }
        return .none
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let pixelImage = pixelImage else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        ctx.setLineCap(.square)
        ctx.setLineWidth(1.0)
        
        let hNum = CGFloat(hPixelNum) / 2.0
        let vNum = CGFloat(vPixelNum) / 2.0
        let imageSize = pixelImage.size()
        
        var deferredPoints: [(PixelCoordinate, CGRect, GridState)] = []
        var centerPoints: [(PixelCoordinate, CGRect, GridState)] = []
        
        for i in 0..<Int(hNum * 2) {
            for j in 0..<Int(vNum * 2) {
                let coord = PixelCoordinate(x: centerCoordinate.x - Int(hNum) + i, y: centerCoordinate.y + Int(vNum) - j)
                if coord.x > 0 && coord.y > 0 && coord.x < Int(floor(imageSize.width)) && coord.y < Int(floor(imageSize.height)) {
                    let rect = CGRect(x: CGFloat(i) * pixelSize.width, y: CGFloat(j) * pixelSize.height, width: pixelSize.width, height: pixelSize.height)
                    let state = gridState(at: coord)
                    if centerCoordinate == coord {
                        centerPoints.append((coord, rect, state))
                    } else {
                        if state != .none {
                            deferredPoints.append((coord, rect, state))
                        } else {
                            ctx.beginPath()
                            ctx.setFillColor(pixelImage.getJSTColor(of: coord.toCGPoint()).toNSColor().cgColor)
                            ctx.setStrokeColor(state.color.cgColor)
                            ctx.addRect(rect)
                            ctx.drawPath(using: .fillStroke)
                        }
                    }
                }
            }
        }
        
        for (coord, rect, state) in deferredPoints {
            ctx.beginPath()
            ctx.setFillColor(pixelImage.getJSTColor(of: coord.toCGPoint()).toNSColor().cgColor)
            ctx.setStrokeColor(state.color.cgColor)
            ctx.setLineWidth(1.0)
            ctx.addRect(rect)
            ctx.drawPath(using: .fillStroke)
            
            let linePositions = [
                [ CGPoint(x: rect.midX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.midY) ],
                [ CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY) ],
                [ CGPoint(x: rect.midX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.midY) ]
            ]
            for linePosition in linePositions {
                if let beginPoint = linePosition.first, let endPoint = linePosition.last {
                    ctx.beginPath()
                    ctx.setStrokeColor(state.color.cgColor)
                    ctx.move(to: beginPoint)
                    ctx.addLine(to: endPoint)
                    ctx.drawPath(using: .stroke)
                }
            }
        }
        
        for (coord, rect, _) in centerPoints {
            ctx.beginPath()
            ctx.setFillColor(pixelImage.getJSTColor(of: coord.toCGPoint()).toNSColor().cgColor)
            ctx.setStrokeColor(GridState.gridCenterLineColor.cgColor)
            ctx.addRect(rect)
            ctx.drawPath(using: .fillStroke)
        }
    }
    
}
