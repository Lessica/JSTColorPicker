//
//  PixelCoordinate.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/3/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

struct PixelCoordinate {
    public static var zero: PixelCoordinate {
        return PixelCoordinate()
    }
    public static var null: PixelCoordinate {
        return PixelCoordinate(x: Int.max, y: Int.max)
    }
    var x: Int = 0
    var y: Int = 0
    init() {}
    init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
    init(_ point: CGPoint) {
        x = Int(floor(point.x))
        y = Int(floor(point.y))
    }
    func toCGPoint() -> CGPoint {
        return CGPoint(x: CGFloat(x), y: CGFloat(y))
    }
}

extension PixelCoordinate: CustomStringConvertible {
    var description: String {
        return "(\(x),\(y))"
    }
}

extension PixelCoordinate: Equatable {
    static func == (lhs: PixelCoordinate, rhs: PixelCoordinate) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }
}
