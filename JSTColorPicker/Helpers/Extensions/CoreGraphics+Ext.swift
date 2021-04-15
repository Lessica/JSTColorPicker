//
//  CoreGraphics+Ext.swift
//  JSTColorPicker
//
//  Created by Darwin on 3/4/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

extension CGPoint {
    func distanceTo(_ point: CGPoint) -> CGFloat {
        let deltaX = abs(x - point.x)
        let deltaY = abs(y - point.y)
        return sqrt(deltaX * deltaX + deltaY * deltaY)
    }
    static var null: CGPoint {
        return CGPoint(x: CGFloat.infinity, y: CGFloat.infinity)
    }
    var isNull: Bool {
        return self.x == CGFloat.infinity || self.y == CGFloat.infinity
    }
    func toPixelCenterCGPoint() -> CGPoint {
        return CGPoint(x: floor(x) + 0.5, y: floor(y) + 0.5)
    }
    func offsetBy(_ point: CGPoint) -> CGPoint {
        return CGPoint(x: x + point.x, y: y + point.y)
    }
    func offsetBy(dx: CGFloat, dy: CGFloat) -> CGPoint {
        return CGPoint(x: x + dx, y: y + dy)
    }
    static prefix func -(_ point: CGPoint) -> CGPoint {
        return CGPoint(x: -point.x, y: -point.y)
    }
}

extension CGSize: Comparable {
    public static func < (lhs: CGSize, rhs: CGSize) -> Bool {
        return lhs.width * lhs.height < rhs.width * rhs.height
    }
    static prefix func -(_ size: CGSize) -> CGSize {
        return CGSize(width: -size.width, height: -size.height)
    }
}

extension CGRect {
    init(at center: CGPoint, radius: CGFloat) {
        self.init(x: center.x - radius, y: center.y - radius, width: radius * 2.0, height: radius * 2.0)
    }
    init(point1: CGPoint, point2: CGPoint) {
        self.init(origin: CGPoint(x: min(point1.x, point2.x), y: min(point1.y, point2.y)), size: CGSize(width: abs(point2.x - point1.x), height: abs(point2.y - point1.y)))
    }
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
    var pointMinXMinY: CGPoint {
        return CGPoint(x: minX, y: minY)
    }
    var pointMinXMaxY: CGPoint {
        return CGPoint(x: minX, y: maxY)
    }
    var pointMaxXMinY: CGPoint {
        return CGPoint(x: maxX, y: minY)
    }
    var pointMaxXMaxY: CGPoint {
        return CGPoint(x: maxX, y: maxY)
    }
    var ratio: CGFloat {
        return width / height
    }
    var smallestWrappingPixelRect: PixelRect {
        return PixelRect(point1: CGPoint(x: floor(minX), y: floor(minY)), point2: CGPoint(x: ceil(maxX), y: ceil(maxY)))
    }
    var largestWrappedPixelRect: PixelRect {
        return PixelRect(point1: CGPoint(x: ceil(minX), y: ceil(minY)), point2: CGPoint(x: floor(maxX), y: floor(maxY)))
    }
    func scaleToAspectFit(in rtarget: CGRect) -> CGFloat {
        // first try to match width
        let s = rtarget.width / self.width;
        // if we scale the height to make the widths equal, does it still fit?
        if self.height * s <= rtarget.height {
            return s
        }
        // no, match height instead
        return rtarget.height / self.height
    }
    func aspectFit(in rtarget: CGRect) -> CGRect {
        let s = scaleToAspectFit(in: rtarget)
        let w = width * s
        let h = height * s
        let x = rtarget.midX - w / 2
        let y = rtarget.midY - h / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }
    func scaleToAspectFit(around rtarget: CGRect) -> CGFloat {
        // fit in the target inside the rectangle instead, and take the reciprocal
        return 1 / rtarget.scaleToAspectFit(in: self)
    }
    func aspectFit(around rtarget: CGRect) -> CGRect {
        let s = scaleToAspectFit(around: rtarget)
        let w = width * s
        let h = height * s
        let x = rtarget.midX - w / 2
        let y = rtarget.midY - h / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }
    func offsetBy(_ point: CGPoint) -> CGRect {
        return CGRect(origin: origin.offsetBy(point), size: size)
    }
    func inset(by insets: NSEdgeInsets) -> CGRect {
        return CGRect(x: origin.x + insets.left, y: origin.y + insets.bottom, width: size.width - insets.left - insets.right, height: size.height - insets.top - insets.bottom)
    }
    func closestPoint(to point: CGPoint) -> CGPoint {
        if contains(point) { return point }
        if point.x < minX && point.y < minY { return CGPoint(x: minX, y: minY) }
        else if point.x > maxX && point.x < minY { return CGPoint(x: maxX, y: minY) }
        else if point.x < minX && point.y > maxY { return CGPoint(x: minX, y: maxY) }
        else if point.x > maxX && point.y > maxY { return CGPoint(x: maxX, y: maxY) }
        else if point.x < minX { return CGPoint(x: minX, y: point.y) }
        else if point.x > maxX { return CGPoint(x: maxX, y: point.y) }
        else if point.y < minY { return CGPoint(x: point.x, y: minY) }
        else if point.y > maxY { return CGPoint(x: point.x, y: maxY) }
        return .null
    }
}
