//
//  PixelColor.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/21/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation
import LuaSwift

class PixelColor: ContentItem {
    
    public fileprivate(set) var coordinate: PixelCoordinate
    public fileprivate(set) var pixelColorRep: JSTPixelColor
    
    enum CodingKeys: String, CodingKey {
        case red, green, blue, alpha, coordinate
    }
    
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
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let red = try container.decode(UInt8.self, forKey: .red)
        let green = try container.decode(UInt8.self, forKey: .green)
        let blue = try container.decode(UInt8.self, forKey: .blue)
        let alpha = try container.decode(UInt8.self, forKey: .alpha)
        
        coordinate = try container.decode(PixelCoordinate.self, forKey: .coordinate)
        pixelColorRep = JSTPixelColor(red: red, green: green, blue: blue, alpha: alpha)
        try super.init(from: decoder)
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
    
    var cssRGBAString: String {
        return pixelColorRep.cssRGBAString
    }
    
    func toNSColor() -> NSColor {
        return pixelColorRep.toNSColor()
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? PixelColor else { return false }
        return self == object
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(red, forKey: .red)
        try container.encode(green, forKey: .green)
        try container.encode(blue, forKey: .blue)
        try container.encode(alpha, forKey: .alpha)
        try container.encode(coordinate, forKey: .coordinate)
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
    
    override func push(_ vm: VirtualMachine) {
        let t = vm.createTable()
        t["id"] = id
        t["similarity"] = similarity
        t["x"] = coordinate.x
        t["y"] = coordinate.y
        t["color"] = intValueWithAlpha
        t.push(vm)
    }
    
    override func kind() -> Kind { return .table }
    
    fileprivate static let typeName: String = "pixel color (table with keys [id,similarity,x,y,color])"
    override class func arg(_ vm: VirtualMachine, value: Value) -> String? {
        if value.kind() != .table { return typeName }
        if let result = Table.arg(vm, value: value) { return result }
        let t = value as! Table
        if !(t["id"] is Number) || !(t["similarity"] is Number) || !(t["x"] is Number)
            || !(t["y"] is Number) || !(t["color"] is Number)
        {
            return typeName
        }
        return nil
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
