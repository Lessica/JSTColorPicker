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
    public static var invalid: PixelRect {
        return PixelRect(x: NSNotFound, y: NSNotFound, width: NSNotFound, height: NSNotFound)
    }
    var origin: PixelCoordinate = PixelCoordinate()
    var size: PixelSize = PixelSize()
    init() {}
    init(x: Int, y: Int, width: Int, height: Int) {
        self.origin = PixelCoordinate(x: x, y: y)
        self.size = PixelSize(width: width, height: height)
    }
    init(origin: PixelCoordinate, size: PixelSize) {
        self.origin = origin
        self.size = size
    }
    init(_ rect: CGRect) {
        origin = PixelCoordinate(rect.origin)
        size = PixelSize(rect.size)
    }
    func toCGRect() -> CGRect {
        return CGRect(origin: origin.toCGPoint(), size: size.toCGSize())
    }
}

extension PixelRect: CustomStringConvertible {
    var description: String {
        return "(\(origin),\(size))"
    }
}

extension PixelRect: Equatable {
    static func == (lhs: PixelRect, rhs: PixelRect) -> Bool {
        return lhs.origin == rhs.origin && lhs.size == rhs.size
    }
}
