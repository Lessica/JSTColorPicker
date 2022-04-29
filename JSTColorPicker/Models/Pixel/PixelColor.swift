//
//  PixelColor.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/21/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation
#if WITH_LUASWIFT
import LuaSwift
#endif
#if WITH_COCOA
import Cocoa

extension NSPasteboard.PasteboardType {
    static let color = NSPasteboard.PasteboardType(rawValue: "public.jst.content.color")
}
#endif

final class PixelColor: ContentItem {
    
    override class var supportsSecureCoding: Bool { true }
    
    public let coordinate: PixelCoordinate
    public let pixelColorRep: JSTPixelColor
    
    enum CodingKeys: String, CodingKey {
        case red, green, blue, alpha, coordinate
    }
    
    init(id: Int, coordinate: PixelCoordinate, color: JSTPixelColor) {
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
        guard let pixelColorRep = coder.decodeObject(of: [JSTPixelColor.self], forKey: "pixelColorRep") as? JSTPixelColor
        else { return nil }
        let coordX = coder.decodeInteger(forKey: "coordinate.x")
        let coordY = coder.decodeInteger(forKey: "coordinate.y")
        guard coordX >= 0, coordY >= 0
        else { return nil }
        self.coordinate = PixelCoordinate(
            x: coordX,
            y: coordY
        )
        self.pixelColorRep = pixelColorRep
        super.init(coder: coder)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let red = try container.decode(UInt8.self, forKey: .red)
        let green = try container.decode(UInt8.self, forKey: .green)
        let blue = try container.decode(UInt8.self, forKey: .blue)
        let alpha = try container.decode(UInt8.self, forKey: .alpha)
        self.pixelColorRep = JSTPixelColor(red: red, green: green, blue: blue, alpha: alpha)
        
        let coordinate = try container.decode(PixelCoordinate.self, forKey: .coordinate)
        guard coordinate.isValid
        else {
            throw Content.Error.notSerialized
        }
        self.coordinate = coordinate
        
        try super.init(from: decoder)
    }
    
    public var rgbValue          : UInt32 { pixelColorRep.rgbValue           }  // [0x0,0xffffff]
    public var red               : UInt8  { pixelColorRep.red                }  // [0x0,0xff]
    public var green             : UInt8  { pixelColorRep.green              }  // [0x0,0xff]
    public var blue              : UInt8  { pixelColorRep.blue               }  // [0x0,0xff]
    public var rgbaValue         : UInt32 { pixelColorRep.rgbaValue          }  // [0x0,0xffffffff]

    public var rgbStruct         : Color.RGB    {
        Color.RGB(r: Float(red) / 0xFF, g: Float(green) / 0xFF, b: Float(blue) / 0xFF)
    }
    public var rgbaStruct        : Color.RGBA   {
        Color.RGBA(r: Float(red) / 0xFF, g: Float(green) / 0xFF, b: Float(blue) / 0xFF, a: Float(alpha) / 0xFF)
    }
    public var hsvStruct         : Color.HSV    {
        rgbStruct.hsv
    }
    public var grayscaleStruct   : Color.G      {
        rgbStruct.grayscale
    }
    
    public var hue               : Float  { hsvStruct.h                      }  // Angle in degrees [0,360] or -1 as Undefined
    public var saturation        : Float  { hsvStruct.s                      }  // [0,1]
    public var brightness        : Float  { hsvStruct.v                      }  // [0,1]
    public var grayscale         : Float  { grayscaleStruct.w                }  // [0,1]

    public var alpha             : UInt8  { pixelColorRep.alpha              }  // [0x0,0xff]
    public var hexString         : String { pixelColorRep.hexString          }
    public var hexStringWithAlpha: String { pixelColorRep.hexStringWithAlpha }
    public var cssString         : String { pixelColorRep.cssString          }
    public var cssRGBAString     : String { pixelColorRep.cssRGBAString      }
    
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
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(red, forKey: .red)
        try container.encode(green, forKey: .green)
        try container.encode(blue, forKey: .blue)
        try container.encode(alpha, forKey: .alpha)
        try container.encode(coordinate, forKey: .coordinate)
    }
    
    override func copy(with zone: NSZone? = nil) -> Any {
        let item = PixelColor(
            id: id,
            coordinate: coordinate,
            color: pixelColorRep.copy() as! JSTPixelColor
        )
        item.tags = tags
        item.similarity = similarity
        item.userInfo = userInfo
        return item
    }

    override func offsetBy(_ offsetPoint: CGPoint) -> Any {
        let item = PixelColor(
            id: id,
            coordinate: coordinate.offsetBy(PixelCoordinate(offsetPoint)),
            color: pixelColorRep.copy() as! JSTPixelColor
        )
        item.tags = tags
        item.similarity = similarity
        item.userInfo = userInfo
        return item
    }
    
    
    // MARK: - LuaSwift.Value
    
#if WITH_LUASWIFT
    override func push(_ vm: VirtualMachine) {
        let t = vm.createTable()
        t["id"]         = id
        t["type"]       = String(describing: PixelColor.self)
        t["name"]       = firstTag ?? ""
        t["tags"]       = vm.createTable(withSequence: tags.elements)
        t["similarity"] = similarity
        t["x"]          = coordinate.x
        t["y"]          = coordinate.y
        t["color"]      = rgbaValue
        t["userInfo"]   = vm.createTable(
            withDictionary: userInfoDict ?? [:], { $0 as String }, { $0 as String }
        )
        t.push(vm)
    }
    
    override func kind() -> Kind { return .table }
    
    private static let typeKeys: [String] = ["id", "type", "name", "tags", "similarity", "x", "y", "color", "userInfo"]
    private static let typeName: String = "\(String(describing: PixelColor.self)) (Table Keys [\(typeKeys.joined(separator: ","))])"
    override class func arg(_ vm: VirtualMachine, value: Value) -> String? {
        if value.kind() != .table { return typeName }
        if let result = Table.arg(vm, value: value) { return result }
        let t = value as! Table
        if  !(t["id"]         is Number)       ||
            !(t["type"]       is String)       ||
            !(t["name"]       is String)       ||
            !(t["tags"]       is Table )       ||
            !(t["similarity"] is Number)       ||
            !(t["x"]          is Number)       ||
            !(t["y"]          is Number)       ||
            !(t["color"]      is Number)       ||
            !(t["userInfo"]   is Table )
        {
            return typeName
        }
        return nil
    }
#endif
    
    
    // MARK: - Pasteboard
    
#if WITH_COCOA
    required convenience init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        guard let item = try? PropertyListDecoder().decode(PixelColor.self, from: propertyList as! Data) else { return nil }
        self.init(id: item.id, coordinate: item.coordinate, color: item.pixelColorRep)
        copyFrom(item)
    }
    
    override class func readableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.color]
    }
    
    override func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.color]
    }
#endif
    
}

extension PixelColor /*: Equatable*/ {
    
    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(coordinate)
        return hasher.finalize()
    }
    
    static func == (lhs: PixelColor, rhs: PixelColor) -> Bool {
        return lhs.coordinate == rhs.coordinate
    }
    
}

extension PixelColor /*: CustomStringConvertible*/ {
    
    override var description: String { "\(pixelColorRep) \(coordinate)" }
    
    override var debugDescription: String { "<#\(id): \(tags.elements) (\(Int(similarity * 100.0))%); \(pixelColorRep) \(coordinate)>" }
    
}

