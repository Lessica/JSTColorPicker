//
//  PixelColor.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/21/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

struct PixelCoordinate {
    var x: Int
    var y: Int
    init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
    init(_ point: CGPoint) {
        x = Int(point.x)
        y = Int(point.y)
    }
    func toCGPoint() -> CGPoint {
        return CGPoint(x: CGFloat(x), y: CGFloat(y))
    }
}

extension PixelCoordinate: CustomStringConvertible {
    var description: String {
        return "(\(x), \(y))"
    }
}

extension PixelCoordinate: Equatable {
    static func == (lhs: PixelCoordinate, rhs: PixelCoordinate) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }
}

class PixelColor: NSObject {
    var id: Int
    var coordinate: PixelCoordinate
    var pixelColorRep: JSTPixelColor
    
    init(id: Int, coordinate: PixelCoordinate, color: JSTPixelColor) {
        self.id = id
        self.coordinate = coordinate
        self.pixelColorRep = color
    }
    
    required init?(coder: NSCoder) {
        guard let pixelColorRep = coder.decodeObject(forKey: "pixelColorRep") as? JSTPixelColor else { return nil }
        self.id = coder.decodeInteger(forKey: "id")
        let coordX = coder.decodeInteger(forKey: "coordinate.x")
        let coordY = coder.decodeInteger(forKey: "coordinate.y")
        self.coordinate = PixelCoordinate(x: coordX, y: coordY)
        self.pixelColorRep = pixelColorRep
    }
    
    deinit {
        debugPrint("- [PixelColor deinit]")
    }
}

extension PixelColor: NSCoding {
    func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(coordinate.x, forKey: "coordinate.x")
        coder.encode(coordinate.y, forKey: "coordinate.y")
        coder.encode(pixelColorRep, forKey: "pixelColorRep")
    }
}

extension PixelColor /*: Equatable*/ {
    static func == (lhs: PixelColor, rhs: PixelColor) -> Bool {
        return lhs.coordinate == rhs.coordinate
    }
}

extension PixelColor: Comparable {
    static func < (lhs: PixelColor, rhs: PixelColor) -> Bool {
        return lhs.id < rhs.id
    }
}

extension PixelColor /*: CustomStringConvertible*/ {
    override var description: String {
        return "(\(id): \(coordinate), \(pixelColorRep))"
    }
}
