//
//  PixelColor.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/21/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

class PixelColor: ContentItem {
    
    var coordinate: PixelCoordinate
    var pixelColorRep: JSTPixelColor
    
    init(id: Int, coordinate: PixelCoordinate, color: JSTPixelColor) {
        self.coordinate    = coordinate
        self.pixelColorRep = color
        super.init(id: id)
    }
    
    init(coordinate: PixelCoordinate, color: JSTPixelColor) {
        self.coordinate    = coordinate
        self.pixelColorRep = color
        super.init(id: 0)
    }
    
    required init?(coder: NSCoder) {
        guard let pixelColorRep = coder.decodeObject(forKey: "pixelColorRep") as? JSTPixelColor else { return nil }
        let coordX = coder.decodeInteger(forKey: "coordinate.x")
        let coordY = coder.decodeInteger(forKey: "coordinate.y")
        self.coordinate    = PixelCoordinate(x: coordX, y: coordY)
        self.pixelColorRep = pixelColorRep
        super.init(coder: coder)
    }
    
    deinit {
        // debugPrint("- [PixelColor deinit]")
    }
    
    var intValue: UInt32 {
        return pixelColorRep.intValue
    }
    
    var intValueWithAlpha: UInt32 {
        return pixelColorRep.intValueWithAlpha
    }
    
    var red: UInt8 {
        return pixelColorRep.red
    }
    
    var green: UInt8 {
        return pixelColorRep.green
    }
    
    var blue: UInt8 {
        return pixelColorRep.blue
    }
    
    var alpha: UInt8 {
        return pixelColorRep.alpha
    }
    
    var hexString: String {
        return pixelColorRep.hexString
    }
    
    var hexStringWithAlpha: String {
        return pixelColorRep.hexStringWithAlpha
    }
    
    var cssString: String {
        return pixelColorRep.cssString
    }
    
    func toNSColor() -> NSColor {
        return pixelColorRep.toNSColor()
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? PixelColor else { return false }
        return self == object
    }
    
    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(coordinate.x, forKey: "coordinate.x")
        coder.encode(coordinate.y, forKey: "coordinate.y")
        coder.encode(pixelColorRep, forKey: "pixelColorRep")
    }
    
    override func copy(with zone: NSZone? = nil) -> Any {
        return PixelColor(id: id, coordinate: coordinate, color: pixelColorRep.copy() as! JSTPixelColor)
    }
}

extension PixelColor /*: Equatable*/ {
    static func == (lhs: PixelColor, rhs: PixelColor) -> Bool {
        return lhs.coordinate == rhs.coordinate
    }
}

extension PixelColor /*: CustomStringConvertible*/ {
    override var description: String {
        return "\(pixelColorRep) \(coordinate)"
    }
}
