//
//  PixelRect.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/3/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation
import LuaSwift

struct PixelRect: Codable {
    
    public static var zero: PixelRect { PixelRect(origin: .zero, size: .zero) }
    
    public static var null: PixelRect { PixelRect(x: Int.max, y: Int.max, width: 0, height: 0) }
    
    public var isNull         : Bool { x == Int.max || y == Int.max }
    public var isEmpty        : Bool { isNull || size == .zero      }
    public var hasStandardized: Bool { width >= 0 && height >= 0    }
    
    public let origin: PixelCoordinate
    public let size:   PixelSize
    
    public var x: Int         { origin.x    }
    public var y: Int         { origin.y    }
    
    public var minX: Int      { origin.x    }
    public var minY: Int      { origin.y    }
    
    public var maxX: Int      { origin.x + size.width  }
    public var maxY: Int      { origin.y + size.height }
    
    public var width: Int     { size.width  }
    public var height: Int    { size.height }
    public var ratio: CGFloat { CGFloat(width) / CGFloat(height) }
    
    public var opposite: PixelCoordinate { PixelCoordinate(x: x + width, y: y + height) }
    
    public var standardized: PixelRect {
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
        self.init(origin: PixelCoordinate(x: Int(min(point1.x, point2.x)), y: Int(min(point1.y, point2.y))), size: PixelSize(width: Int(abs(point2.x - point1.x)), height: Int(abs(point2.y - point1.y))))
    }
    
    init(coordinate1: PixelCoordinate, coordinate2: PixelCoordinate) {
        self.init(origin: PixelCoordinate(x: min(coordinate1.x, coordinate2.x), y: min(coordinate1.y, coordinate2.y)), size: PixelSize(width: abs(coordinate2.x - coordinate1.x), height: abs(coordinate2.y - coordinate1.y)))
    }
    
    public func toCGRect() -> CGRect {
        if isNull {
            return .null
        }
        return CGRect(origin: origin.toCGPoint(), size: size.toCGSize())
    }
    
    public func contains(_ coordinate: PixelCoordinate) -> Bool {
        if coordinate.x >= x && coordinate.y >= y && coordinate.x < x + width && coordinate.y < y + height {
            return true
        }
        return false
    }
    
    public func contains(_ rect: PixelRect) -> Bool {
        if x <= rect.x && y <= rect.y && x + width >= rect.x + rect.width && y + height >= rect.y + rect.height {
            return true
        }
        return false
    }
    
    public func intersection(_ rect: PixelRect) -> PixelRect {
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
            sizeWidth = r1.origin.x + r1.size.width - rect.origin.x
        } else {
            sizeWidth = r2.origin.x + r2.size.width - rect.origin.x
        }
        
        var sizeHeight: Int
        if (r1.origin.y + r1.size.height < r2.origin.y + r2.size.height) {
            sizeHeight = r1.origin.y + r1.size.height - rect.origin.y
        } else {
            sizeHeight = r2.origin.y + r2.size.height - rect.origin.y
        }
        return PixelRect(x: originX, y: originY, width: sizeWidth, height: sizeHeight)
    }
    
}

extension PixelRect: CustomStringConvertible {
    
    var description: String {
        return "(\(origin.x),\(origin.y),w\(size.width),h\(size.height))"
    }
    
}

extension PixelRect: Hashable {
    
    static func == (lhs: PixelRect, rhs: PixelRect) -> Bool {
        return lhs.origin == rhs.origin && lhs.size == rhs.size
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(origin)
        hasher.combine(size)
    }
    
}

extension PixelRect: LuaSwift.Value {
    
    func push(_ vm: VirtualMachine) {
        let t = vm.createTable()
        t["minX"] = minX
        t["minY"] = minY
        t["maxX"] = maxX
        t["maxY"] = maxY
        t["width"] = width
        t["height"] = height
        t.push(vm)
    }
    
    func kind() -> Kind { return .table }
    
    private static let typeKeys: [String] = ["minX", "minY", "maxX", "maxY", "width", "height"]
    private static let typeName: String = "\(String(describing: PixelRect.self)) (Table Keys [\(typeKeys.joined(separator: ","))])"
    static func arg(_ vm: VirtualMachine, value: Value) -> String? {
        if value.kind() != .table { return typeName }
        if let result = Table.arg(vm, value: value) { return result }
        let t = value as! Table
        if  !(t["minX"]   is Number)  ||
                !(t["minY"]   is Number)  ||
                !(t["maxX"]   is Number)  ||
                !(t["maxY"]   is Number)  ||
                !(t["width"]  is Number)  ||
                !(t["height"] is Number)
        { return typeName }
        return nil
    }
    
}
