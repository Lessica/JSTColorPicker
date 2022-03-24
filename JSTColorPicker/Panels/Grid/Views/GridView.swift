//
//  GridView.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/20/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa


final class GridView: NSView {
    
    // MARK: - Types
    
    enum SizeLevel: UInt {
        case small = 17
        case medium = 15
        case large = 13
        case extraLarge = 11
        
        static func level(atDefaultValue value: Int) -> SizeLevel {
            if value == 0 {
                return .small
            }
            else if value == 1 {
                return .medium
            }
            else if value == 2 {
                return .large
            }
            else if value == 3 {
                return .extraLarge
            }
            return .medium
        }
    }
    
    enum AnimationSpeed: TimeInterval {
        case slow = 0.8
        case medium = 0.6
        case fast = 0.4
        case extreme = 0.2
        
        static func speed(atDefaultValue value: Int) -> AnimationSpeed {
            if value == 0 {
                return .slow
            }
            else if value == 1 {
                return .medium
            }
            else if value == 2 {
                return .fast
            }
            else if value == 3 {
                return .extreme
            }
            return .medium
        }
    }
    
    private enum State: CaseIterable {
        
        case none
        case colorOccupied
        case areaOccupied
        case bothOccupied
        case center
        
        static let gridLineWidth: CGFloat = 1.0
        static let gridLineColor = NSColor(white: 1.0, alpha: 0.3)
        static let gridCenterLineColor = NSColor(white: 0.0, alpha: 0.3)
        
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
        
        var defaultColor: NSColor {
            switch self {
            case .colorOccupied:
                return State.gridColorOccupiedLineColor
            case .areaOccupied:
                return State.gridAreaOccupiedLineColor
            case .bothOccupied:
                return State.gridBothOccupiedLineColor
            case .center:
                return State.gridCenterLineColor
            default:
                return State.gridLineColor
            }
        }
        
        func color(with colorPresets: [State: NSColor]) -> NSColor {
            return colorPresets[self] ?? defaultColor
        }
        
    }
    
    weak var dataSource: ScreenshotLoader?
    override var isOpaque: Bool { false }
    override var wantsDefaultClipping: Bool { false }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = true
        
        layer!.isOpaque = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layerContentsPlacement = .scaleAxesIndependently
        
        applyFromDefaults()
        addSubview(centerOverlay)
    }
    
    
    // MARK: - Layout
    
    var shouldDrawAnnotators: Bool = false
    private var pixelSize: CGSize = .zero
    
    private lazy var centerOverlay: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = .white
        return view
    }()
    
    var pixelSizeLevel: SizeLevel = .medium {
        didSet {
            pixelSize = CGSize(
                width: bounds.width / CGFloat(pixelSizeLevel.rawValue),
                height: bounds.height / CGFloat(pixelSizeLevel.rawValue)
            )
            centerOverlay.frame = CGRect(
                origin: bounds.center
                    .offsetBy(
                        dx: -pixelSize.width / 2,
                        dy: -pixelSize.height / 2
                    ),
                size: pixelSize
            )
            needsDisplay = true
        }
    }
    
    func applyFromDefaults() {
        pixelSizeLevel = SizeLevel.level(atDefaultValue: UserDefaults.standard[.gridViewSizeLevel])
        animationSpeed = AnimationSpeed.speed(atDefaultValue: UserDefaults.standard[.gridViewAnimationSpeed])
    }
    
    
    // MARK: - State
    
    private var pixelImage: PixelImage? { dataSource?.screenshot?.image }
    
    var centerCoordinate: PixelCoordinate = PixelCoordinate.zero {
        didSet {
            updateDisplayIfNeeded()
        }
    }
    
    private func gridState(at coordinate: PixelCoordinate) -> State {
        guard let content = dataSource?.screenshot?.content else { return .none }
        let isOccupiedByColor =
            shouldDrawAnnotators ? 
                (content.items.first(where: { ($0 as? PixelColor)?.coordinate == coordinate }) != nil) : false
        let isOccupiedByArea  =
            shouldDrawAnnotators ?
                (content.items.first(where: { (($0 as? PixelArea)?.rect.contains(coordinate) ?? false) }) != nil) : false
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
    
    
    // MARK: - Drawing
    
    var colorGridColorAnnotatorColor: NSColor? {
        didSet {
            updateColorPresets()
        }
    }
    var colorGridAreaAnnotatorColor: NSColor? {
        didSet {
            updateColorPresets()
        }
    }
    private var colorPresets: [State: NSColor]?
    
    private func updateColorPresets() {
        var presets = [State: NSColor]()
        if let colorGridColorAnnotatorColor = colorGridColorAnnotatorColor {
            presets[.colorOccupied] = colorGridColorAnnotatorColor
        }
        if let colorGridAreaAnnotatorColor = colorGridAreaAnnotatorColor {
            presets[.areaOccupied] = colorGridAreaAnnotatorColor
        }
        if let colorGridColorAnnotatorColor = colorGridColorAnnotatorColor,
           let colorGridAreaAnnotatorColor = colorGridAreaAnnotatorColor {
            presets[.bothOccupied] = colorGridColorAnnotatorColor.blended(
                withFraction: 1.0,
                of: colorGridAreaAnnotatorColor
            )
        }
        self.colorPresets = presets
    }
    
    func updateDisplayIfNeeded() {
        guard window?.isVisible ?? false else { return }
        setNeedsDisplayAll()
    }
    
    func setNeedsDisplayAll() {
        setNeedsDisplay(bounds)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard !inLiveResize else { return }
        guard let pixelImage = pixelImage else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        var points: [State: [(state: State, coordinate: PixelCoordinate, rect: CGRect)]] = [:]
        State.allCases.forEach({ points[$0] = [] })
        
        let pixelNum = CGFloat(pixelSizeLevel.rawValue) / 2.0
        let imageSize = pixelImage.size
        for i in 0..<Int(pixelNum * 2) {
            for j in 0..<Int(pixelNum * 2) {
                let coord = PixelCoordinate(x: centerCoordinate.x - Int(pixelNum) + i, y: centerCoordinate.y + Int(pixelNum) - j)
                if coord.x > 0 && coord.y > 0 && coord.x < imageSize.width && coord.y < imageSize.height {
                    let state = gridState(at: coord)
                    points[state]?.append((state, coord, CGRect(x: CGFloat(i) * pixelSize.width, y: CGFloat(j) * pixelSize.height, width: pixelSize.width, height: pixelSize.height)))
                }
            }
        }
        
        let drawColorPresets = self.colorPresets ?? [:]
        let drawClosure = { (state: State, coord: PixelCoordinate, rect: CGRect) -> Void in
            let color: CGColor = pixelImage.rawColor(at: coord)?.toNSColor().cgColor ?? .clear
            ctx.setStrokeColor(state.color(with: drawColorPresets).cgColor)
            ctx.setFillColor(color)
            ctx.addRect(rect)
            ctx.drawPath(using: .fillStroke)
            
            var needsStroke = false
            for linePosition in state.lines(for: rect) {
                if let beginPoint = linePosition.first, let endPoint = linePosition.last {
                    ctx.move(to: beginPoint)
                    ctx.addLine(to: endPoint)
                    needsStroke = true
                }
            }
            if needsStroke { ctx.strokePath() }
        }
        
        // ctx.saveGState()
        ctx.setLineWidth(State.gridLineWidth)
        State.allCases.forEach({ points[$0]?.forEach(drawClosure) })
        // ctx.restoreGState()
        
    }
    
    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        needsDisplay = true
    }
    
    
    // MARK: - Animation
    
    var animationSpeed: AnimationSpeed = .medium
    
    var animating: Bool = false {
        didSet {
            if animating {
                shimAnimation(false)
            }
        }
    }
    
    private func shimAnimation(_ opaque: Bool) {
        if !animating { return }
        NSAnimationContext.runAnimationGroup({ [weak self] (context) in
            guard let self = self else { return }
            context.duration = self.animationSpeed.rawValue
            self.centerOverlay.animator().alphaValue = opaque ? 1.0 : 0.0
        }) { [weak self] in
            guard let self = self else { return }
            self.shimAnimation(!opaque)
        }
    }
    
}
