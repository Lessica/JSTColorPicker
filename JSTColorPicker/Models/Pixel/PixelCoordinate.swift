//
//  PixelCoordinate.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/3/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

public struct PixelCoordinate: Codable {
    
    static var zero: PixelCoordinate { PixelCoordinate(x: 0, y: 0) }
    
    static var null: PixelCoordinate { PixelCoordinate(x: Int.max, y: Int.max) }
    
    var isNull: Bool { self == PixelCoordinate.null }
    var isValid: Bool { x >= 0 && y >= 0 && !isNull }
    
    let x: Int
    let y: Int
    
    init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
    
    init(_ point: CGPoint) {
        x = Int(point.x)
        y = Int(point.y)
    }
    
    func toCGPoint() -> CGPoint {
        if isNull {
            return .null
        }
        return CGPoint(x: CGFloat(x), y: CGFloat(y))
    }

    func offsetBy(_ offsetCoordinate: PixelCoordinate) -> PixelCoordinate {
        return PixelCoordinate(self.toCGPoint().offsetBy(offsetCoordinate.toCGPoint()))
    }
    
}

extension PixelCoordinate: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        return "(\(x),\(y))"
    }
    
    public var debugDescription: String {
        return "coordinate{x\(x),y\(y)}"
    }
    
}

extension PixelCoordinate: Hashable {
    
    public static func == (lhs: PixelCoordinate, rhs: PixelCoordinate) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
    
}
