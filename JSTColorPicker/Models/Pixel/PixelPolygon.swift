//
//  PixelPolygon.swift
//  JSTColorPicker
//
//  Created by Rachel on 5/17/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Foundation
import LuaSwift

extension NSPasteboard.PasteboardType {
    static let polygon = NSPasteboard.PasteboardType(rawValue: "public.jst.content.polygon")
}

final class PixelPolygon: ContentItem {
    
    override class var supportsSecureCoding: Bool { true }
    
    public let coordinates: [PixelCoordinate]
    
    override init(id: Int) {
        self.coordinates = [PixelCoordinate]()
        super.init(id: id)
    }
    
    enum CodingKeys: String, CodingKey {
        case coordinates
    }
    
    required init?(coder: NSCoder) {
        let coordCount = coder.decodeInteger(forKey: "coordinates.count")
        var coordinates = [PixelCoordinate]()
        for coordIdx in 0..<coordCount {
            let coord = PixelCoordinate(
                x: coder.decodeInteger(forKey: "coordinates[\(coordIdx)].x"),
                y: coder.decodeInteger(forKey: "coordinates[\(coordIdx)].y")
            )
            guard coord.isValid else { return nil }
            coordinates.append(coord)
        }
        self.coordinates = coordinates
        super.init(coder: coder)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.coordinates = try container.decode([PixelCoordinate].self, forKey: .coordinates)
        try super.init(from: decoder)
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? PixelArea else { return false }
        return self == object
    }
    
    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        for (coordIdx, coord) in coordinates.enumerated() {
            coder.encode(coord.x, forKey: "coordinates[\(coordIdx)].x")
            coder.encode(coord.y, forKey: "coordinates[\(coordIdx)].y")
        }
        coder.encode(coordinates.count, forKey: "coordinates.count")
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(coordinates, forKey: .coordinates)
    }
    
    override func copy(with zone: NSZone? = nil) -> Any {
        let item = PixelPolygon(id: id)
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


