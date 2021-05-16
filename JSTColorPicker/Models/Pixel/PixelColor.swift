//
//  PixelColor.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/21/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation
import LuaSwift

extension NSPasteboard.PasteboardType {
    static let color = NSPasteboard.PasteboardType(rawValue: "public.jst.content.color")
}

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
        guard let pixelColorRep = coder.decodeObject(of: [JSTPixelColor.self], forKey: "pixelColorRep") as? JSTPixelColor else { return nil }
        self.coordinate    = PixelCoordinate(
            x: coder.decodeInteger(forKey: "coordinate.x"),
            y: coder.decodeInteger(forKey: "coordinate.y")
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
        
        coordinate = try container.decode(PixelCoordinate.self, forKey: .coordinate)
        pixelColorRep = JSTPixelColor(red: red, green: green, blue: blue, alpha: alpha)
        try super.init(from: decoder)
    }
    
    public var rgbValue          : UInt32 { pixelColorRep.rgbValue           }  // [0x0,0xffffff]
    public var red               : UInt8  { pixelColorRep.red                }  // [0x0,0xff]
    public var green             : UInt8  { pixelColorRep.green              }  // [0x0,0xff]
    public var blue              : UInt8  { pixelColorRep.blue               }  // [0x0,0xff]
    public lazy var rgbStruct    : RGB =
        {
            RGB(r: Float(red) / 0xFF, g: Float(green) / 0xFF, b: Float(blue) / 0xFF)
        }()
    public var rgbaValue         : UInt32 { pixelColorRep.rgbaValue          }  // [0x0,0xffffffff]
    public lazy var rgbaStruct   : RGBA =
        {
            RGBA(r: Float(red) / 0xFF, g: Float(green) / 0xFF, b: Float(blue) / 0xFF, a: Float(alpha) / 0xFF)
        }()
    public lazy var hsvStruct    : HSV =
        {
            rgbStruct.hsv
        }()
    public var hue               : Float  { hsvStruct.h                      }  // Angle in degrees [0,360] or -1 as Undefined
    public var saturation        : Float  { hsvStruct.s                      }  // [0,1]
    public var brightness        : Float  { hsvStruct.v                      }  // [0,1]
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
        let item = PixelColor(id: id, coordinate: coordinate, color: pixelColorRep.copy() as! JSTPixelColor)
        item.tags = tags
        item.similarity = similarity
        return item
    }
    
    override func push(_ vm: VirtualMachine) {
        let t = vm.createTable()
        t["id"]         = id
        t["name"]       = firstTag ?? ""
        t["tags"]       = vm.createTable(withSequence: tags.contents)
        t["similarity"] = similarity
        t["x"]          = coordinate.x
        t["y"]          = coordinate.y
        t["color"]      = rgbaValue
        t.push(vm)
    }
    
    override func kind() -> Kind { return .table }
    
    private static let typeKeys: [String] = ["id", "name", "tags", "similarity", "x", "y", "color"]
    private static let typeName: String = "\(String(describing: PixelColor.self)) (Table Keys [\(typeKeys.joined(separator: ","))])"
    override class func arg(_ vm: VirtualMachine, value: Value) -> String? {
        if value.kind() != .table { return typeName }
        if let result = Table.arg(vm, value: value) { return result }
        let t = value as! Table
        if  !(t["id"]         is Number)       ||
                !(t["name"]       is String)       ||
                !(t["tags"]       is Table )       ||
                !(t["similarity"] is Number)       ||
                !(t["x"]          is Number)       ||
                !(t["y"]          is Number)       ||
                !(t["color"]      is Number)
        {
            return typeName
        }
        return nil
    }
    
    
    // MARK: - Pasteboard
    
    required convenience init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        guard let item = try? PropertyListDecoder().decode(PixelColor.self, from: propertyList as! Data) else { return nil }
        self.init(id: item.id, coordinate: item.coordinate, color: item.pixelColorRep)
        self.tags = item.tags
        self.similarity = item.similarity
        copyFrom(item)
    }
    
    override class func readableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.color]
    }
    
    override func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.color]
    }
    
}

extension PixelColor /*: Equatable*/ {
    
    static func == (lhs: PixelColor, rhs: PixelColor) -> Bool {
        return lhs.coordinate == rhs.coordinate
    }
    
}

extension PixelColor /*: CustomStringConvertible*/ {
    
    override var description: String { "\(pixelColorRep) \(coordinate)" }
    
    override var debugDescription: String { "<#\(id): \(tags.contents) (\(Int(similarity * 100.0))%); \(pixelColorRep) \(coordinate)>" }
    
}

