//
//  PixelSegment.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/5/16.
//  Copyright © 2021 JST. All rights reserved.
//

import Foundation

public struct PixelSegment: Codable {
    
    var coordinate1: PixelCoordinate { PixelCoordinate(x: x1, y: y1) }
    var coordinate2: PixelCoordinate { PixelCoordinate(x: x2, y: y2) }
    
    var isValid: Bool { coordinate1.isValid && coordinate2.isValid && coordinate1 != coordinate2 }
    
    let x1: Int
    let y1: Int
    let x2: Int
    let y2: Int
    
    init(x1: Int, y1: Int, x2: Int, y2: Int) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }
    
    init(coordinate1: PixelCoordinate, coordinate2: PixelCoordinate) {
        self.x1 = coordinate1.x
        self.y1 = coordinate1.y
        self.x2 = coordinate2.x
        self.y2 = coordinate2.y
    }

    func offsetBy(_ offsetCoordinate: PixelCoordinate) -> PixelSegment {
        return PixelSegment(
            coordinate1: coordinate1.offsetBy(offsetCoordinate),
            coordinate2: coordinate2.offsetBy(offsetCoordinate)
        )
    }
    
}

extension PixelSegment: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        return "{x1:\(x1),y1:\(y1),x2:\(x2),y2:\(y2)}"
    }
    
    public var debugDescription: String {
        return "segment{x1:\(x1),y1:\(y1),x2:\(x2),y2:\(y2)}"
    }
    
}

extension PixelSegment: Hashable {
    
    public static func == (lhs: PixelSegment, rhs: PixelSegment) -> Bool {
        return (lhs.coordinate1 == rhs.coordinate1 && lhs.coordinate2 == rhs.coordinate2) || (lhs.coordinate1 == rhs.coordinate2 && lhs.coordinate2 == rhs.coordinate1)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x1)
        hasher.combine(y1)
        hasher.combine(x2)
        hasher.combine(y2)
    }
    
}
