//
//  Screenshot+Print.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/16/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

extension CGContext {

    /// Transforms the user coordinate system in a context
    /// such that the y-axis is flipped.
    func flipYAxis(height: CGFloat) {
        concatenate(
            CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: height)
        )
    }

}

final class ScreenshotPrintingView: NSView {
    
    enum TagPosition: Int {
        case outer = 0
        case inner
    }
    
    enum TagSize: Int {
        case regular = 0
        case small
    }
    
    private enum TagCorner: Int {
        
        // outer / inner
        case topLeft
        case bottomRight
        case topRight
        case bottomLeft
        
        // outer only
        case leftTop
        case leftBottom
        case rightTop
        case rightBottom
    }
    
    let screenshot: Screenshot
    
    private var image: PixelImage { screenshot.image! }
    private var content: Content { screenshot.content! }
    private var printInfo: NSPrintInfo { screenshot.printInfo }
    
    init(
        screenshot: Screenshot,
        tagPosition: TagPosition = .outer,
        tagSize: TagSize = .regular,
        drawsOutline: Bool = true
    ) throws {
        
        guard let image = screenshot.image else {
            throw Screenshot.Error.invalidImage
        }
        
        guard screenshot.content != nil else {
            throw Screenshot.Error.invalidContent
        }
        
        self.screenshot = screenshot
        self.tagPosition = tagPosition
        self.tagSize = tagSize
        self.drawsOutline = drawsOutline
        
        let drawBounds = CGRect(
            origin: .zero,
            size: image.bounds
                .toCGRect()
                .aspectFit(in: screenshot.printInfo.imageablePageBounds)
                .inset(by: NSEdgeInsets(
                    top: screenshot.printInfo.topMargin,
                    left: screenshot.printInfo.leftMargin,
                    bottom: screenshot.printInfo.bottomMargin,
                    right: screenshot.printInfo.rightMargin
                ))
                .size
        )
        
        debugPrint(drawBounds)
        super.init(frame: drawBounds)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var isFlipped: Bool { true }
    
    // MARK: - Additional Print Options
    
    var tagPosition: TagPosition = .outer
    var tagSize: TagSize = .regular
    var drawsOutline: Bool = true
    
    private let borderWidth: CGFloat = 6.0
    private let outerTagHorizontalMargin: CGFloat = 4.0
    private let innerTagHorizontalMargin: CGFloat = 2.0
    private let outerTagVericalMargin: CGFloat = 0.5
    private let innerTagVericalMargin: CGFloat = 0.5
    
    private let outlineWidth: CGFloat = 0.5
    private var outlineColor: CGColor { drawsOutline ? .white : .clear }
    
    private let defaultFillColor = NSColor.controlAccentColor
    private let backgroundAlpha: CGFloat = 0.2
    
    private let lightTextColor = NSColor.white
    private let darkTextColor = NSColor.black
    
    private var tagFontSize: CGFloat { tagSize == .regular ? NSFont.systemFontSize : NSFont.smallSystemFontSize }
    private var tagHorizontalMargin: CGFloat { tagPosition == .outer ? outerTagHorizontalMargin : innerTagHorizontalMargin }
    private var tagVericalMargin: CGFloat { tagPosition == .outer ? outerTagVericalMargin : innerTagVericalMargin }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let gContext = NSGraphicsContext.current
        else { return }
        
        let cgContext = gContext.cgContext
        
        cgContext.saveGState()
        cgContext.flipYAxis(height: bounds.height)
        cgContext.draw(image.cgImage, in: bounds)
        cgContext.restoreGState()
        
        cgContext.saveGState()
        
        var labelRects = [CGRect]()
        let scale = max(bounds.width / image.size.toCGSize().width, bounds.height / image.size.toCGSize().height)
        let scaledBorderWidth = borderWidth * scale
        let areaItems = content.items.compactMap({ $0 as? PixelArea })
        for areaItem in areaItems {
            
            let areaRect = areaItem.rect.toCGRect().multipliedBy(dx: scale, dy: scale)
            let areaInnerRect = areaRect.insetBy(dx: scaledBorderWidth / 2.0, dy: scaledBorderWidth / 2.0)
            
            var tagName: String?
            var fillColor: NSColor
            var textColor: NSColor
            if let tagManager = screenshot.tagManager,
               let firstTagString = areaItem.firstTag,
               let firstTag = tagManager.managedTag(of: firstTagString)
            {
                tagName = firstTag.name
                fillColor = firstTag.color
                textColor = (firstTag.color.isLightColor ?? false) ? darkTextColor : lightTextColor
            }
            else
            {
                tagName = nil
                fillColor = defaultFillColor
                textColor = (defaultFillColor.isLightColor ?? false) ? darkTextColor : lightTextColor
            }
            
            var proposedCorner: TagCorner?
            var proposedRect: CGRect?
            var proposedTagName: NSAttributedString?
            var externalLabelOffset: CGPoint = .zero
            
            if let tagName = tagName {
                
                let textFont = NSFont.systemFont(ofSize: tagFontSize * scale)
                let attrTagName = NSAttributedString(string: tagName, attributes: [
                    .font: textFont, .foregroundColor: textColor])
                let tagSize = attrTagName.size()
                var tagRect = CGRect(origin: .zero, size: CGSize(
                    width: tagSize.width,
                    height: tagSize.height
                )).insetBy(dx: -tagHorizontalMargin * scale * 2.0, dy: -tagVericalMargin * scale * 2.0)
                
                var possibleCorner: TagCorner? = nil
                let possibleTagName = attrTagName
                
                let widthAllowed = tagRect.width + scaledBorderWidth * 2.0 < areaRect.width
                let heightAllowed = tagRect.height + scaledBorderWidth * 2.0 < areaRect.height
                
                var conditionSatisfied = false
                
                repeat {
                    if tagPosition == .outer
                    {
                        // top left
                        if widthAllowed {
                            
                            tagRect.origin = areaRect.pointMinXMinY.offsetBy(
                                dx: scaledBorderWidth,
                                dy: -tagRect.height
                            )

                            possibleCorner = .topLeft
                            externalLabelOffset = CGPoint(x: 0, y: scaledBorderWidth / 4.0)
                        }

                        if labelRects.allSatisfy({ !$0.intersects(tagRect) }) && bounds.contains(tagRect) {
                            conditionSatisfied = true
                            break
                        }
                        
                        // bottom right
                        if widthAllowed {

                            tagRect.origin = areaRect.pointMaxXMaxY.offsetBy(
                                dx: -scaledBorderWidth - tagRect.width,
                                dy: 0
                            )

                            possibleCorner = .bottomRight
                            externalLabelOffset = CGPoint(x: 0, y: -scaledBorderWidth / 4.0)
                        }

                        if labelRects.allSatisfy({ !$0.intersects(tagRect) }) && bounds.contains(tagRect) {
                            conditionSatisfied = true
                            break
                        }
                        
                        // top right
                        if widthAllowed {

                            tagRect.origin = areaRect.pointMaxXMinY.offsetBy(
                                dx: -scaledBorderWidth - tagRect.width,
                                dy: -tagRect.height
                            )

                            possibleCorner = .topRight
                            externalLabelOffset = CGPoint(x: 0, y: scaledBorderWidth / 4.0)
                        }

                        if labelRects.allSatisfy({ !$0.intersects(tagRect) }) && bounds.contains(tagRect) {
                            conditionSatisfied = true
                            break
                        }
                        
                        // bottom left
                        if widthAllowed {

                            tagRect.origin = areaRect.pointMinXMaxY.offsetBy(
                                dx: scaledBorderWidth,
                                dy: 0
                            )

                            possibleCorner = .bottomLeft
                            externalLabelOffset = CGPoint(x: 0, y: -scaledBorderWidth / 4.0)
                        }

                        if labelRects.allSatisfy({ !$0.intersects(tagRect) }) && bounds.contains(tagRect) {
                            conditionSatisfied = true
                            break
                        }
                        
                        // left top
                        if heightAllowed {

                            tagRect.origin = areaRect.pointMinXMinY.offsetBy(
                                dx: -tagRect.width,
                                dy: scaledBorderWidth
                            )

                            possibleCorner = .leftTop
                            externalLabelOffset = CGPoint(x: scaledBorderWidth / 4.0, y: 0)
                        }

                        if labelRects.allSatisfy({ !$0.intersects(tagRect) }) && bounds.contains(tagRect) {
                            conditionSatisfied = true
                            break
                        }
                        
                        // left bottom
                        if heightAllowed {

                            tagRect.origin = areaRect.pointMinXMaxY.offsetBy(
                                dx: -tagRect.width,
                                dy: -scaledBorderWidth - tagRect.height
                            )

                            possibleCorner = .leftBottom
                            externalLabelOffset = CGPoint(x: scaledBorderWidth / 4.0, y: 0)
                        }

                        if labelRects.allSatisfy({ !$0.intersects(tagRect) }) && bounds.contains(tagRect) {
                            conditionSatisfied = true
                            break
                        }
                        
                        // right top
                        if heightAllowed {
                            
                            tagRect.origin = areaRect.pointMaxXMinY.offsetBy(
                                dx: 0,
                                dy: scaledBorderWidth
                            )
                            
                            possibleCorner = .rightTop
                            externalLabelOffset = CGPoint(x: -scaledBorderWidth / 4.0, y: 0)
                        }
                        
                        if labelRects.allSatisfy({ !$0.intersects(tagRect) }) && bounds.contains(tagRect) {
                            conditionSatisfied = true
                            break
                        }
                        
                        // right bottom
                        if heightAllowed {
                            
                            tagRect.origin = areaRect.pointMaxXMaxY.offsetBy(
                                dx: 0,
                                dy: -scaledBorderWidth - tagRect.height
                            )
                            
                            possibleCorner = .rightBottom
                            externalLabelOffset = CGPoint(x: -scaledBorderWidth / 4.0, y: 0)
                        }
                        
                        if labelRects.allSatisfy({ !$0.intersects(tagRect) }) && bounds.contains(tagRect) {
                            conditionSatisfied = true
                            break
                        }
                    }
                    else if tagPosition == .inner
                    {
                        // top left
                        if widthAllowed {

                            tagRect.origin = areaInnerRect.pointMinXMinY.offsetBy(
                                dx: 0,
                                dy: 0
                            )

                            possibleCorner = .topLeft
                            externalLabelOffset = CGPoint(x: -scaledBorderWidth / 4.0, y: -scaledBorderWidth / 4.0)
                        }

                        if labelRects.allSatisfy({ !$0.intersects(tagRect) }) && areaInnerRect.contains(tagRect) && areaInnerRect.height > tagRect.height * 2.0 {
                            conditionSatisfied = true
                            break
                        }
                        
                        // bottom right
                        if widthAllowed {

                            tagRect.origin = areaInnerRect.pointMaxXMaxY.offsetBy(
                                dx: -tagRect.width,
                                dy: -tagRect.height
                            )

                            possibleCorner = .bottomRight
                            externalLabelOffset = CGPoint(x: scaledBorderWidth / 4.0, y: scaledBorderWidth / 4.0)
                        }

                        if labelRects.allSatisfy({ !$0.intersects(tagRect) }) && areaInnerRect.contains(tagRect) && areaInnerRect.height > tagRect.height * 2.0 {
                            conditionSatisfied = true
                            break
                        }
                        
                        // top right
                        if widthAllowed {

                            tagRect.origin = areaInnerRect.pointMaxXMinY.offsetBy(
                                dx: -tagRect.width,
                                dy: 0
                            )

                            possibleCorner = .topRight
                            externalLabelOffset = CGPoint(x: scaledBorderWidth / 4.0, y: -scaledBorderWidth / 4.0)
                        }

                        if labelRects.allSatisfy({ !$0.intersects(tagRect) }) && areaInnerRect.contains(tagRect) && areaInnerRect.height > tagRect.height * 2.0 {
                            conditionSatisfied = true
                            break
                        }
                        
                        // bottom left
                        if widthAllowed {

                            tagRect.origin = areaInnerRect.pointMinXMaxY.offsetBy(
                                dx: 0,
                                dy: -tagRect.height
                            )

                            possibleCorner = .bottomLeft
                            externalLabelOffset = CGPoint(x: -scaledBorderWidth / 4.0, y: scaledBorderWidth / 4.0)
                        }

                        if labelRects.allSatisfy({ !$0.intersects(tagRect) }) && areaInnerRect.contains(tagRect) && areaInnerRect.height > tagRect.height * 2.0 {
                            conditionSatisfied = true
                            break
                        }
                    }
                } while (false)
                
                if conditionSatisfied,
                   let possibleCorner = possibleCorner
                {
                    proposedRect = tagRect
                    proposedCorner = possibleCorner
                    proposedTagName = possibleTagName
                    
                    labelRects.append(tagRect)
                } else {
                    proposedRect = nil
                    proposedCorner = nil
                    proposedTagName = nil
                }
            }
            
            let backgroundColor = fillColor.withAlphaComponent(backgroundAlpha)
            
            // draw background
            cgContext.saveGState()
            cgContext.setFillColor(backgroundColor.cgColor)
            cgContext.addRect(areaInnerRect)
            cgContext.fillPath()
            cgContext.restoreGState()
            
            // draw rounded border
            cgContext.saveGState()
            cgContext.setLineWidth(outlineWidth * scale)
            cgContext.setStrokeColor(outlineColor)
            cgContext.setFillColor(fillColor.cgColor)
            
            // draw inner path
            if tagPosition == .inner,
               let proposedCorner = proposedCorner,
               let proposedRect = proposedRect
            {
                if proposedCorner == .topLeft
                {
                    cgContext.move(to: areaInnerRect.pointMinXMidY)
                    cgContext.addLine(to: proposedRect.pointMinXMaxY)
                    cgContext.addArc(
                        tangent1End: proposedRect.pointMaxXMaxY,
                        tangent2End: proposedRect.pointMaxXMidY,
                        radius: scaledBorderWidth
                    )
                    cgContext.addLine(to: proposedRect.pointMaxXMinY)
                    cgContext.addArc(
                        tangent1End: areaInnerRect.pointMaxXMinY,
                        tangent2End: areaInnerRect.pointMaxXMidY,
                        radius: scaledBorderWidth / 2.0
                    )
                    cgContext.addArc(
                        tangent1End: areaInnerRect.pointMaxXMaxY,
                        tangent2End: areaInnerRect.pointMidXMaxY,
                        radius: scaledBorderWidth / 2.0
                    )
                    cgContext.addArc(
                        tangent1End: areaInnerRect.pointMinXMaxY,
                        tangent2End: areaInnerRect.pointMinXMidY,
                        radius: scaledBorderWidth / 2.0
                    )
                    cgContext.closePath()
                }
                else if proposedCorner == .topRight
                {
                    cgContext.move(to: areaInnerRect.pointMidXMinY)
                    cgContext.addLine(to: proposedRect.pointMinXMinY)
                    cgContext.addArc(
                        tangent1End: proposedRect.pointMinXMaxY,
                        tangent2End: proposedRect.pointMidXMaxY,
                        radius: scaledBorderWidth
                    )
                    cgContext.addLine(to: proposedRect.pointMaxXMaxY)
                    cgContext.addArc(
                        tangent1End: areaInnerRect.pointMaxXMaxY,
                        tangent2End: areaInnerRect.pointMidXMaxY,
                        radius: scaledBorderWidth / 2.0
                    )
                    cgContext.addArc(
                        tangent1End: areaInnerRect.pointMinXMaxY,
                        tangent2End: areaInnerRect.pointMinXMidY,
                        radius: scaledBorderWidth / 2.0
                    )
                    cgContext.addArc(
                        tangent1End: areaInnerRect.pointMinXMinY,
                        tangent2End: areaInnerRect.pointMidXMinY,
                        radius: scaledBorderWidth / 2.0
                    )
                    cgContext.closePath()
                }
                else if proposedCorner == .bottomLeft
                {
                    cgContext.move(to: areaInnerRect.pointMidXMaxY)
                    cgContext.addLine(to: proposedRect.pointMaxXMaxY)
                    cgContext.addArc(
                        tangent1End: proposedRect.pointMaxXMinY,
                        tangent2End: proposedRect.pointMidXMinY,
                        radius: scaledBorderWidth
                    )
                    cgContext.addLine(to: proposedRect.pointMinXMinY)
                    cgContext.addArc(
                        tangent1End: areaInnerRect.pointMinXMinY,
                        tangent2End: areaInnerRect.pointMidXMinY,
                        radius: scaledBorderWidth / 2.0
                    )
                    cgContext.addArc(
                        tangent1End: areaInnerRect.pointMaxXMinY,
                        tangent2End: areaInnerRect.pointMaxXMidY,
                        radius: scaledBorderWidth / 2.0
                    )
                    cgContext.addArc(
                        tangent1End: areaInnerRect.pointMaxXMaxY,
                        tangent2End: areaInnerRect.pointMidXMaxY,
                        radius: scaledBorderWidth / 2.0
                    )
                    cgContext.closePath()
                }
                else if proposedCorner == .bottomRight
                {
                    cgContext.move(to: areaInnerRect.pointMaxXMidY)
                    cgContext.addLine(to: proposedRect.pointMaxXMinY)
                    cgContext.addArc(
                        tangent1End: proposedRect.pointMinXMinY,
                        tangent2End: proposedRect.pointMinXMidY,
                        radius: scaledBorderWidth
                    )
                    cgContext.addLine(to: proposedRect.pointMinXMaxY)
                    cgContext.addArc(
                        tangent1End: areaInnerRect.pointMinXMaxY,
                        tangent2End: areaInnerRect.pointMinXMidY,
                        radius: scaledBorderWidth / 2.0
                    )
                    cgContext.addArc(
                        tangent1End: areaInnerRect.pointMinXMinY,
                        tangent2End: areaInnerRect.pointMidXMinY,
                        radius: scaledBorderWidth / 2.0
                    )
                    cgContext.addArc(
                        tangent1End: areaInnerRect.pointMaxXMinY,
                        tangent2End: areaInnerRect.pointMaxXMidY,
                        radius: scaledBorderWidth / 2.0
                    )
                    cgContext.closePath()
                }
            } else {
                
                // no attached tag or outer mode
                cgContext.addPath(CGPath(
                    roundedRect: areaInnerRect,
                    cornerWidth: scaledBorderWidth / 2.0,
                    cornerHeight: scaledBorderWidth / 2.0,
                    transform: nil
                ))
            }
            
            // draw outer path
            if tagPosition == .outer,
               let proposedCorner = proposedCorner,
               let proposedRect = proposedRect
            {
                if proposedCorner == .topLeft || proposedCorner == .topRight
                {
                    cgContext.move(to: areaRect.pointMinXMidY)
                    cgContext.addArc(
                        tangent1End: areaRect.pointMinXMinY,
                        tangent2End: areaRect.pointMinXMinY.offsetBy(
                            dx: abs(proposedRect.minX - areaRect.minX) / 2.0, dy: 0),
                        radius: scaledBorderWidth
                    )
                    cgContext.addLine(to: proposedRect.pointMinXMaxY)
                    cgContext.addArc(
                        tangent1End: proposedRect.pointMinXMinY,
                        tangent2End: proposedRect.pointMidXMinY,
                        radius: scaledBorderWidth
                    )
                    cgContext.addArc(
                        tangent1End: proposedRect.pointMaxXMinY,
                        tangent2End: proposedRect.pointMaxXMidY,
                        radius: scaledBorderWidth
                    )
                    cgContext.addLine(to: proposedRect.pointMaxXMaxY)
                    cgContext.addArc(
                        tangent1End: areaRect.pointMaxXMinY,
                        tangent2End: areaRect.pointMaxXMidY,
                        radius: scaledBorderWidth
                    )
                    cgContext.addArc(
                        tangent1End: areaRect.pointMaxXMaxY,
                        tangent2End: areaRect.pointMidXMaxY,
                        radius: scaledBorderWidth
                    )
                    cgContext.addArc(
                        tangent1End: areaRect.pointMinXMaxY,
                        tangent2End: areaRect.pointMinXMidY,
                        radius: scaledBorderWidth
                    )
                    cgContext.closePath()
                }
                else if proposedCorner == .bottomLeft || proposedCorner == .bottomRight
                {
                    cgContext.move(to: areaRect.pointMaxXMidY)
                    cgContext.addArc(
                        tangent1End: areaRect.pointMaxXMaxY,
                        tangent2End: areaRect.pointMaxXMaxY.offsetBy(
                            dx: -abs(areaRect.maxX - proposedRect.maxX) / 2.0, dy: 0),
                        radius: scaledBorderWidth
                    )
                    cgContext.addLine(to: proposedRect.pointMaxXMinY)
                    cgContext.addArc(
                        tangent1End: proposedRect.pointMaxXMaxY,
                        tangent2End: proposedRect.pointMidXMaxY,
                        radius: scaledBorderWidth
                    )
                    cgContext.addArc(
                        tangent1End: proposedRect.pointMinXMaxY,
                        tangent2End: proposedRect.pointMinXMidY,
                        radius: scaledBorderWidth
                    )
                    cgContext.addLine(to: proposedRect.pointMinXMinY)
                    cgContext.addArc(
                        tangent1End: areaRect.pointMinXMaxY,
                        tangent2End: areaRect.pointMinXMidY,
                        radius: scaledBorderWidth
                    )
                    cgContext.addArc(
                        tangent1End: areaRect.pointMinXMinY,
                        tangent2End: areaRect.pointMidXMinY,
                        radius: scaledBorderWidth
                    )
                    cgContext.addArc(
                        tangent1End: areaRect.pointMaxXMinY,
                        tangent2End: areaRect.pointMaxXMidY,
                        radius: scaledBorderWidth
                    )
                    cgContext.closePath()
                }
                else if proposedCorner == .leftTop || proposedCorner == .leftBottom
                {
                    cgContext.move(to: areaRect.pointMidXMaxY)
                    cgContext.addArc(
                        tangent1End: areaRect.pointMinXMaxY,
                        tangent2End: areaRect.pointMinXMaxY.offsetBy(
                            dx: 0, dy: -abs(areaRect.maxY - proposedRect.maxY) / 2.0),
                        radius: scaledBorderWidth
                    )
                    cgContext.addLine(to: proposedRect.pointMaxXMaxY)
                    cgContext.addArc(
                        tangent1End: proposedRect.pointMinXMaxY,
                        tangent2End: proposedRect.pointMinXMidY,
                        radius: scaledBorderWidth
                    )
                    cgContext.addArc(
                        tangent1End: proposedRect.pointMinXMinY,
                        tangent2End: proposedRect.pointMidXMinY,
                        radius: scaledBorderWidth
                    )
                    cgContext.addLine(to: proposedRect.pointMaxXMinY)
                    cgContext.addArc(
                        tangent1End: areaRect.pointMinXMinY,
                        tangent2End: areaRect.pointMidXMinY,
                        radius: scaledBorderWidth
                    )
                    cgContext.addArc(
                        tangent1End: areaRect.pointMaxXMinY,
                        tangent2End: areaRect.pointMaxXMidY,
                        radius: scaledBorderWidth
                    )
                    cgContext.addArc(
                        tangent1End: areaRect.pointMaxXMaxY,
                        tangent2End: areaRect.pointMidXMaxY,
                        radius: scaledBorderWidth
                    )
                    cgContext.closePath()
                }
                else if proposedCorner == .rightTop || proposedCorner == .rightBottom
                {
                    cgContext.move(to: areaRect.pointMidXMinY)
                    cgContext.addArc(
                        tangent1End: areaRect.pointMaxXMinY,
                        tangent2End: areaRect.pointMaxXMinY.offsetBy(
                            dx: 0, dy: abs(proposedRect.minY - areaRect.minY) / 2.0),
                        radius: scaledBorderWidth
                    )
                    cgContext.addLine(to: proposedRect.pointMinXMinY)
                    cgContext.addArc(
                        tangent1End: proposedRect.pointMaxXMinY,
                        tangent2End: proposedRect.pointMaxXMidY,
                        radius: scaledBorderWidth
                    )
                    cgContext.addArc(
                        tangent1End: proposedRect.pointMaxXMaxY,
                        tangent2End: proposedRect.pointMidXMaxY,
                        radius: scaledBorderWidth
                    )
                    cgContext.addLine(to: proposedRect.pointMinXMaxY)
                    cgContext.addArc(
                        tangent1End: areaRect.pointMaxXMaxY,
                        tangent2End: areaRect.pointMidXMaxY,
                        radius: scaledBorderWidth
                    )
                    cgContext.addArc(
                        tangent1End: areaRect.pointMinXMaxY,
                        tangent2End: areaRect.pointMinXMidY,
                        radius: scaledBorderWidth
                    )
                    cgContext.addArc(
                        tangent1End: areaRect.pointMinXMinY,
                        tangent2End: areaRect.pointMidXMinY,
                        radius: scaledBorderWidth
                    )
                    cgContext.closePath()
                }
            } else {
                
                // no attached tag or inner mode
                cgContext.addPath(CGPath(
                    roundedRect: areaRect,
                    cornerWidth: scaledBorderWidth,
                    cornerHeight: scaledBorderWidth,
                    transform: nil
                ))
            }
            
            cgContext.drawPath(using: .eoFillStroke)
            
            // draw label
            if let proposedRect = proposedRect,
               let proposedTagName = proposedTagName
            {
                proposedTagName.draw(
                    at: proposedRect.pointMinXMinY.offsetBy(
                        dx: externalLabelOffset.x + tagHorizontalMargin * scale * 2.0, dy: externalLabelOffset.y + tagVericalMargin * scale * 2.0)
                )
            }
            
            cgContext.restoreGState()
        }
        
        cgContext.restoreGState()
    }
}

extension Screenshot {
    
    fileprivate var tagManager: TagListSource? {
        (windowControllers.first as? WindowController)?.contentController.tagManager
    }
    
    override var printInfo: NSPrintInfo {
        get {
            let printInfo = super.printInfo
            printInfo.topMargin = 0
            printInfo.leftMargin = 0
            printInfo.rightMargin = 0
            printInfo.bottomMargin = 0
            return printInfo
        }
        set {
            super.printInfo = newValue
        }
    }
    
    override func preparePageLayout(_ pageLayout: NSPageLayout) -> Bool {
        let prepared = super.preparePageLayout(pageLayout)
        pageLayout.addAccessoryController(PrintController(inPageSetup: true))
        return prepared
    }
    
    override func shouldChangePrintInfo(_ newPrintInfo: NSPrintInfo) -> Bool {
        debugPrint(newPrintInfo)
        return true
    }
    
    override func printOperation(withSettings printSettings: [NSPrintInfo.AttributeKey : Any]) throws -> NSPrintOperation {
        return NSPrintOperation(
            view: try ScreenshotPrintingView(
                screenshot: self,
                tagPosition: ScreenshotPrintingView.TagPosition(rawValue: UserDefaults.standard[.printTagPositionLevel]) ?? .outer,
                tagSize: ScreenshotPrintingView.TagSize(rawValue: UserDefaults.standard[.printTagSizeLevel]) ?? .regular,
                drawsOutline: UserDefaults.standard[.drawOutlinesInPrinting]
            ),
            printInfo: self.printInfo
        )
    }
}
