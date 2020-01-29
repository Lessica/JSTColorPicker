//
//  PixelColor.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/21/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

struct PixelCoordinate: CustomStringConvertible, Equatable {
    var x: Int
    var y: Int
    init(_ point: CGPoint) {
        x = Int(point.x)
        y = Int(point.y)
    }
    func toCGPoint() -> CGPoint {
        return CGPoint(x: CGFloat(x), y: CGFloat(y))
    }
    var description: String {
        return "(\(x), \(y))"
    }
    static func == (lhs: PixelCoordinate, rhs: PixelCoordinate) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }
}

class PixelColor {
    var id: Int
    var coordinate: PixelCoordinate
    var pixelColorRep: JSTPixelColor
    
    init(id: Int, coordinate: PixelCoordinate, color: JSTPixelColor) {
        self.id = id
        self.coordinate = coordinate
        self.pixelColorRep = color
    }
}

extension PixelColor: Equatable {
    static func == (lhs: PixelColor, rhs: PixelColor) -> Bool {
        return lhs.coordinate == rhs.coordinate
    }
}

extension PixelColor: CustomStringConvertible {
    var description: String {
        return "(\(id): \(coordinate), \(pixelColorRep))"
    }
}
