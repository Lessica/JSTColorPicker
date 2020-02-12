//
//  ColorGridView.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/20/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

enum GridState: CaseIterable {
    case none
    case colorOccupied
    case areaOccupied
    case bothOccupied
    case center
    
    static let gridLineColor = NSColor.textBackgroundColor
    static let gridCenterLineColor = NSColor.textColor
    static let gridColorOccupiedLineColor = NSColor.red
    static let gridAreaOccupiedLineColor = NSColor.blue
    static let gridBothOccupiedLineColor = NSColor.red
    
    func lines(for rect: CGRect) -> [[CGPoint]] {
        switch self {
        case .colorOccupied:
            return [
                [ CGPoint(x: rect.midX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.midY) ],
                [ CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY) ],
                [ CGPoint(x: rect.midX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.midY) ]
            ]
        case .areaOccupied:
            return [
                [ CGPoint(x: rect.midX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.midY) ],
                [ CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.minY) ],
                [ CGPoint(x: rect.midX, y: rect.minY), CGPoint(x: rect.minX, y: rect.midY) ]
            ]
        case .bothOccupied:
            return [
                [ CGPoint(x: rect.midX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.midY) ],
                [ CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY) ],
                [ CGPoint(x: rect.midX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.midY) ],
                [ CGPoint(x: rect.midX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.midY) ],
                [ CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.minY) ],
                [ CGPoint(x: rect.midX, y: rect.minY), CGPoint(x: rect.minX, y: rect.midY) ]
            ]
        default:
            return []
        }
    }
    
    var color: NSColor {
        switch self {
        case .colorOccupied:
            return GridState.gridColorOccupiedLineColor
        case .areaOccupied:
            return GridState.gridAreaOccupiedLineColor
        case .bothOccupied:
            return GridState.gridBothOccupiedLineColor
        case .center:
            return GridState.gridCenterLineColor
        default:
            return GridState.gridLineColor
        }
    }
}

class ColorGridView: NSView {
    
    weak var dataSource: ScreenshotLoader?
    var centerCoordinate: PixelCoordinate = PixelCoordinate.zero {
        didSet {
            updateDisplayIfNeeded()
        }
    }
    func updateDisplayIfNeeded() {
        guard let shouldTrack = window?.isVisible else { return }
        if shouldTrack {
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
    fileprivate var pixelImage: PixelImage? {
        return dataSource?.screenshot?.image
    }
    
    fileprivate func shimAnimation(_ opaque: Bool) {
        if !animating { return }
        NSAnimationContext.runAnimationGroup({ [weak self] (context) in
            guard let self = self else { return }
            context.duration = 0.6
            self.centerOverlay.animator().alphaValue = opaque ? 1.0 : 0.0
        }) { [weak self] in
            guard let self = self else { return }
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
        if centerCoordinate == coordinate {
            return .center
        }
        else if isOccupiedByColor && isOccupiedByArea {
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
        
        var points: [GridState: [(state: GridState, coordinate: PixelCoordinate, rect: CGRect)]] = [:]
        GridState.allCases.forEach({ points[$0] = [] })
        
        let hNum = CGFloat(hPixelNum) / 2.0
        let vNum = CGFloat(vPixelNum) / 2.0
        let imageSize = pixelImage.size
        for i in 0..<Int(hNum * 2) {
            for j in 0..<Int(vNum * 2) {
                let coord = PixelCoordinate(x: centerCoordinate.x - Int(hNum) + i, y: centerCoordinate.y + Int(vNum) - j)
                if coord.x > 0 && coord.y > 0 && coord.x < imageSize.width && coord.y < imageSize.height {
                    let state = gridState(at: coord)
                    points[state]?.append((state, coord, CGRect(x: CGFloat(i) * pixelSize.width, y: CGFloat(j) * pixelSize.height, width: pixelSize.width, height: pixelSize.height)))
                }
            }
        }
        
        let drawClosure = { (state: GridState, coord: PixelCoordinate, rect: CGRect) -> Void in
            ctx.setStrokeColor(state.color.cgColor)
            ctx.setFillColor(pixelImage.color(at: coord).toNSColor().cgColor)
            ctx.addRect(rect)
            ctx.drawPath(using: .fillStroke)
            for linePosition in state.lines(for: rect) {
                if let beginPoint = linePosition.first, let endPoint = linePosition.last {
                    ctx.move(to: beginPoint)
                    ctx.addLine(to: endPoint)
                    ctx.drawPath(using: .stroke)
                }
            }
        }
        
        ctx.saveGState()
        ctx.setLineCap(.square)
        ctx.setLineWidth(1.0)
        GridState.allCases.forEach({ points[$0]?.forEach(drawClosure) })
        ctx.restoreGState()
        
    }
    
}
