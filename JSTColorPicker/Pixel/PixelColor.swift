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
    
    override class var supportsSecureCoding: Bool {
        return true
    }
    
    public fileprivate(set) var coordinate: PixelCoordinate
    public fileprivate(set) var pixelColorRep: JSTPixelColor
    
    public init(id: Int, coordinate: PixelCoordinate, color: JSTPixelColor) {
        self.coordinate    = coordinate
        self.pixelColorRep = color
        super.init(id: id)
    }
    
    public init(coordinate: PixelCoordinate, color: JSTPixelColor) {
        self.coordinate    = coordinate
        self.pixelColorRep = color
        super.init(id: 0)
    }
    
    required init?(coder: NSCoder) {
        guard let pixelColorRep = coder.decodeObject(of: [JSTPixelColor.self], forKey: "pixelColorRep") as? JSTPixelColor else { return nil }
        self.coordinate    = PixelCoordinate(
            x: coder.decodeInteger(forKey: "coordinate.x"),
            y: coder.decodeInteger(forKey: "coordinate.y")
        )
        self.pixelColorRep = pixelColorRep
        super.init(coder: coder)
    }
    
    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    deinit {
        // debugPrint("- [PixelColor deinit]")
    }
    
    public var rgbValue: UInt32 {
        return pixelColorRep.rgbValue
    }
    
    public var rgbaValue: UInt32 {
        return pixelColorRep.rgbaValue
    }
    
    public var red: UInt8 {
        return pixelColorRep.red
    }
    
    public var green: UInt8 {
        return pixelColorRep.green
    }
    
    public var blue: UInt8 {
        return pixelColorRep.blue
    }
    
    public var alpha: UInt8 {
        return pixelColorRep.alpha
    }
    
    public var hexString: String {
        return pixelColorRep.hexString
    }
    
    public var hexStringWithAlpha: String {
        return pixelColorRep.hexStringWithAlpha
    }
    
    public var cssString: String {
        return pixelColorRep.cssString
    }
    
    public var cssRGBAString: String {
        return pixelColorRep.cssRGBAString
    }
    
    public func toNSColor() -> NSColor {
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
        let item = PixelColor(id: id, coordinate: coordinate, color: pixelColorRep.copy() as! JSTPixelColor)
        item.tags = tags
        return item
    }
    
    override func push(_ vm: VirtualMachine) {
        let t = vm.createTable()
        t["id"]    = id
        t["tags"]  = vm.createTable(withSequence: tags)
        t["x"]     = coordinate.x
        t["y"]     = coordinate.y
        t["color"] = rgbaValue
        t.push(vm)
    }
    
    override func kind() -> Kind { return .table }
    
    fileprivate static let typeName: String = "pixel color (table with keys [id,tags,x,y,color])"
    override class func arg(_ vm: VirtualMachine, value: Value) -> String? {
        if value.kind() != .table { return typeName }
        if let result = Table.arg(vm, value: value) { return result }
        let t = value as! Table
        if  !(t["id"]    is Number)     ||
            !(t["tags"]  is Table)      ||
            !(t["x"]     is Number)     ||
            !(t["y"]     is Number)     ||
            !(t["color"] is Number)
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
    
    override var description: String { "\(pixelColorRep) \(coordinate)" }
    
    override var debugDescription: String { "<#\(id): \(tags); \(pixelColorRep) \(coordinate)>" }
    
}
