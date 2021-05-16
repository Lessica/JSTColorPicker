//
//  PixelArea.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/3/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation
import LuaSwift

extension NSPasteboard.PasteboardType {
    static let area = NSPasteboard.PasteboardType(rawValue: "public.jst.content.area")
}

final class PixelArea: ContentItem {
    
    override class var supportsSecureCoding: Bool { true }
    
    public let rect: PixelRect
    
    public init(id: Int, rect: PixelRect) {
        self.rect = rect
        super.init(id: id)
    }
    
    public init(rect: PixelRect) {
        self.rect = rect
        super.init(id: 0)
    }
    
    enum CodingKeys: String, CodingKey {
        case rect
    }
    
    required init?(coder: NSCoder) {
        let rectX = coder.decodeInteger(forKey: "rect.origin.x")
        let rectY = coder.decodeInteger(forKey: "rect.origin.y")
        let rectW = coder.decodeInteger(forKey: "rect.size.width")
        let rectH = coder.decodeInteger(forKey: "rect.size.height")
        guard rectX >= 0, rectY >= 0, rectW > 0, rectH > 0 else
        {
            return nil
        }
        self.rect  = PixelRect(
            x: rectX,
            y: rectY,
            width: rectW,
            height: rectH
        )
        super.init(coder: coder)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rect = try container.decode(PixelRect.self, forKey: .rect)
        guard rect.isValid else
        {
            throw Content.Error.notSerialized
        }
        self.rect = rect
        try super.init(from: decoder)
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? PixelArea else { return false }
        return self == object
    }
    
    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(rect.origin.x, forKey: "rect.origin.x")
        coder.encode(rect.origin.y, forKey: "rect.origin.y")
        coder.encode(rect.size.width, forKey: "rect.size.width")
        coder.encode(rect.size.height, forKey: "rect.size.height")
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rect, forKey: .rect)
    }
    
    override func copy(with zone: NSZone? = nil) -> Any {
        let item = PixelArea(id: id, rect: rect)
        item.tags = tags
        item.similarity = similarity
        return item
    }
    
    override func push(_ vm: VirtualMachine) {
        let t = vm.createTable()
        t["id"]              = id
        t["type"]            = String(describing: PixelArea.self)
        t["name"]            = firstTag ?? ""
        t["tags"]            = vm.createTable(withSequence: tags.contents)
        t["similarity"]      = similarity
        t["x"]               = rect.x
        t["y"]               = rect.y
        t["minX"]            = rect.minX
        t["minY"]            = rect.minY
        t["maxX"]            = rect.maxX
        t["maxY"]            = rect.maxY
        t["width"]           = rect.width
        t["height"]          = rect.height
        t.push(vm)
    }
    
    override func kind() -> Kind { return .table }
    
    private static let typeKeys: [String] = [
        "id", "type", "name", "tags", "similarity",
        "x", "y", "minX", "minY", "maxX", "maxY",
        "width", "height"
    ]
    private static let typeName: String = "\(String(describing: PixelArea.self)) (Table Keys [\(typeKeys.joined(separator: ","))])"
    override class func arg(_ vm: VirtualMachine, value: Value) -> String? {
        if value.kind() != .table { return typeName }
        if let result = Table.arg(vm, value: value) { return result }
        let t = value as! Table
        if  !(t["id"]         is  Number)        ||
                !(t["type"]       is  String)        ||
                !(t["name"]       is  String)        ||
                !(t["tags"]       is  Table )        ||
                !(t["similarity"] is  Number)        ||
                !(t["x"]          is  Number)        ||
                !(t["y"]          is  Number)        ||
                !(t["minX"]       is  Number)        ||
                !(t["minY"]       is  Number)        ||
                !(t["maxX"]       is  Number)        ||
                !(t["maxY"]       is  Number)        ||
                !(t["width"]      is  Number)        ||
                !(t["height"]     is  Number)
        {
            return typeName
        }
        return nil
    }
    
    
    // MARK: - Pasteboard
    
    required convenience init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        guard let item = try? PropertyListDecoder().decode(PixelArea.self, from: propertyList as! Data) else { return nil }
        self.init(id: item.id, rect: item.rect)
        copyFrom(item)
    }
    
    override class func readableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.area]
    }
    
    override func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.area]
    }
    
}

extension PixelArea /*: Equatable*/ {
    
    static func == (lhs: PixelArea, rhs: PixelArea) -> Bool {
        return lhs.rect == rhs.rect
    }
    
}

extension PixelArea /*: CustomStringConvertible*/ {
    
    override var description: String { rect.description }
    
    override var debugDescription: String { "<#\(id): \(tags.contents) (\(Int(similarity * 100.0))%); \(rect.description)>" }
    
}

