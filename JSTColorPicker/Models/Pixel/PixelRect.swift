//
//  PixelRect.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/3/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

public struct PixelRect: Codable {
    
    static var zero: PixelRect { PixelRect(origin: .zero, size: .zero) }
    
    static var null: PixelRect { PixelRect(x: Int.max, y: Int.max, width: 0, height: 0) }
    
    var isNull           : Bool { x == Int.max || y == Int.max   }
    var isEmpty          : Bool { isNull || size == .zero        }
    var isValid          : Bool { origin.isValid && size.isValid }
    var hasStandardized  : Bool { width >= 0 && height >= 0      }
    
    let origin: PixelCoordinate
    let size:   PixelSize
    
    var x: Int         { origin.x    }
    var y: Int         { origin.y    }
    
    var minX: Int      { origin.x    }
    var minY: Int      { origin.y    }
    
    var maxX: Int      { origin.x + size.width  }
    var maxY: Int      { origin.y + size.height }
    
    var width: Int     { size.width  }
    var height: Int    { size.height }
    var ratio: CGFloat { CGFloat(width) / CGFloat(height) }
    
    var opposite: PixelCoordinate { PixelCoordinate(x: x + width, y: y + height) }
    
    var standardized: PixelRect {
        var originX: Int = origin.x
        var originY: Int = origin.y
        var sizeWidth: Int = size.width
        var sizeHeight: Int = size.height
        if sizeWidth < 0 {
            originX += sizeWidth
            sizeWidth = -sizeWidth
        }
        if sizeHeight < 0 {
            originY += sizeHeight
            sizeHeight = -sizeHeight
        }
        return PixelRect(x: originX, y: originY, width: sizeWidth, height: sizeHeight)
    }
    
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
        self.init(
            origin: PixelCoordinate(
                x: Int(min(point1.x, point2.x)),
                y: Int(min(point1.y, point2.y))
            ),
            size: PixelSize(
                width: Int(abs(point2.x - point1.x)),
                height: Int(abs(point2.y - point1.y))
            )
        )
    }
    
    init(coordinate1: PixelCoordinate, coordinate2: PixelCoordinate) {
        self.init(
            origin: PixelCoordinate(
                x: min(coordinate1.x, coordinate2.x),
                y: min(coordinate1.y, coordinate2.y)
            ),
            size: PixelSize(
                width: abs(coordinate2.x - coordinate1.x),
                height: abs(coordinate2.y - coordinate1.y)
            )
        )
    }
    
    func toCGRect() -> CGRect {
        if isNull {
            return .null
        }
        return CGRect(origin: origin.toCGPoint(), size: size.toCGSize())
    }

    func offsetBy(_ offsetCoordinate: PixelCoordinate) -> PixelRect {
        return PixelRect(origin: origin.offsetBy(offsetCoordinate), size: size)
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
    
    func intersection(_ rect: PixelRect) -> PixelRect {
        var r1 = self
        var r2 = rect
        
        /* If both of them are empty we can return r2 as an empty rect,
         so this covers all cases: */
        if (r1.isEmpty) { return r2 }
        else if (r2.isEmpty) { return r1 }
        
        r1 = r1.standardized
        r2 = r2.standardized
        
        if (r1.origin.x + r1.size.width  <= r2.origin.x ||
                r2.origin.x + r2.size.width  <= r1.origin.x ||
                r1.origin.y + r1.size.height <= r2.origin.y ||
                r2.origin.y + r2.size.height <= r1.origin.y)
        {
            return .null
        }
        
        let originX = (r1.origin.x > r2.origin.x ? r1.origin.x : r2.origin.x)
        let originY = (r1.origin.y > r2.origin.y ? r1.origin.y : r2.origin.y)
        
        var sizeWidth: Int
        if (r1.origin.x + r1.size.width < r2.origin.x + r2.size.width) {
            sizeWidth = r1.origin.x + r1.size.width - originX
        } else {
            sizeWidth = r2.origin.x + r2.size.width - originX
        }
        
        var sizeHeight: Int
        if (r1.origin.y + r1.size.height < r2.origin.y + r2.size.height) {
            sizeHeight = r1.origin.y + r1.size.height - originY
        } else {
            sizeHeight = r2.origin.y + r2.size.height - originY
        }
        return PixelRect(x: originX, y: originY, width: sizeWidth, height: sizeHeight)
    }
    
}

extension PixelRect: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        return "{x:\(origin.x),y:\(origin.y),w:\(size.width),h:\(size.height)}"
    }
    
    public var debugDescription: String {
        return "rect{x:\(origin.x),y:\(origin.y),w:\(size.width),h:\(size.height)}"
    }
    
}

extension PixelRect: Hashable {
    
    public static func == (lhs: PixelRect, rhs: PixelRect) -> Bool {
        return lhs.origin == rhs.origin && lhs.size == rhs.size
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(origin)
        hasher.combine(size)
    }
    
}
