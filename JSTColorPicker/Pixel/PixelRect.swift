//
//  PixelRect.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/3/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

struct PixelRect {
    public static var zero: PixelRect {
        return PixelRect()
    }
    public static var null: PixelRect {
        return PixelRect(x: Int.max, y: Int.max, width: 0, height: 0)
    }
    public var isNull: Bool {
        return self == PixelRect.null
    }
    var origin: PixelCoordinate = PixelCoordinate()
    var size: PixelSize         = PixelSize()
    var x: Int      { return origin.x    }
    var y: Int      { return origin.y    }
    var width: Int  { return size.width  }
    var height: Int { return size.height }
    var opposite: PixelCoordinate { return PixelCoordinate(x: x + width, y: y + height) }
    init() {}
    init(x: Int, y: Int, width: Int, height: Int) {
        self.origin = PixelCoordinate(x: x, y: y)
        self.size   = PixelSize(width: width, height: height)
    }
    init(origin: PixelCoordinate, size: PixelSize) {
        self.origin = origin
        self.size   = size
    }
    init(_ rect: CGRect) {
        origin = PixelCoordinate(rect.origin)
        size   = PixelSize(rect.size)
    }
    init(point1: CGPoint, point2: CGPoint) {
        self.init(origin: PixelCoordinate(x: Int(floor(min(point1.x, point2.x))), y: Int(floor(min(point1.y, point2.y)))), size: PixelSize(width: Int(floor(abs(point2.x - point1.x))), height: Int(floor(abs(point2.y - point1.y)))))
    }
    init(coordinate1: PixelCoordinate, coordinate2: PixelCoordinate) {
        self.init(origin: PixelCoordinate(x: min(coordinate1.x, coordinate2.x), y: min(coordinate1.y, coordinate2.y)), size: PixelSize(width: abs(coordinate2.x - coordinate1.x), height: abs(coordinate2.y - coordinate1.y)))
    }
    func toCGRect() -> CGRect {
        return CGRect(origin: origin.toCGPoint(), size: size.toCGSize())
    }
    func contains(_ coordinate: PixelCoordinate) -> Bool {
        if coordinate.x >= x && coordinate.y >= y && coordinate.x < x + width && coordinate.y < y + height {
            return true
        }
        return false
    }
    func contains(_ rect: PixelRect) -> Bool {
        if x <= rect.x && y <= rect.y && x + width >= rect.x + rect.width && y + height >= rect.y + rect.height {
            return true
        }
        return false
    }
}

extension PixelRect: CustomStringConvertible {
    var description: String {
        return "(\(origin.x),\(origin.y),w\(size.width),h\(size.height))"
    }
}

extension PixelRect: Equatable {
    static func == (lhs: PixelRect, rhs: PixelRect) -> Bool {
        return lhs.origin == rhs.origin && lhs.size == rhs.size
    }
}
