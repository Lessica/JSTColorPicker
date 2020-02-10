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
    func toCGRect() -> CGRect {
        return CGRect(origin: origin.toCGPoint(), size: size.toCGSize())
    }
    func contains(_ coordinate: PixelCoordinate) -> Bool {
        if coordinate.x >= origin.x && coordinate.y >= origin.y && coordinate.x < origin.x + size.width && coordinate.y < origin.y + size.height {
            return true
        }
        return false
    }
}

extension PixelRect: CustomStringConvertible {
    var description: String {
        return "(\(origin.x),\(origin.y),\(size.width),\(size.height))"
    }
}

extension PixelRect: Equatable {
    static func == (lhs: PixelRect, rhs: PixelRect) -> Bool {
        return lhs.origin == rhs.origin && lhs.size == rhs.size
    }
}
