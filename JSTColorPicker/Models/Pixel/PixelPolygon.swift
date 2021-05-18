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
    
    public init(id: Int, coordinates: [PixelCoordinate]) {
        self.coordinates = coordinates
        super.init(id: id)
    }
    
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
        let item = PixelPolygon(id: id, coordinates: coordinates)
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
        t["coordinates"]     = vm.createTable(withSequence: coordinates)
        t.push(vm)
    }
    
    override func kind() -> Kind { return .table }
    
    private static let typeKeys: [String] = [
        "id", "type", "name", "tags", "similarity",
        "coordinates"
    ]
    private static let typeName: String = "\(String(describing: PixelPolygon.self)) (Table Keys [\(typeKeys.joined(separator: ","))])"
    override class func arg(_ vm: VirtualMachine, value: Value) -> String? {
        if value.kind() != .table { return typeName }
        if let result = Table.arg(vm, value: value) { return result }
        let t = value as! Table
        if  !(t["id"]              is  Number)        ||
                !(t["type"]        is  String)        ||
                !(t["name"]        is  String)        ||
                !(t["tags"]        is  Table )        ||
                !(t["similarity"]  is  Number)        ||
                !(t["coordinates"] is  Table )
        {
            return typeName
        }
        return nil
    }
    
    
    // MARK: - Pasteboard
    
    required convenience init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        guard let item = try? PropertyListDecoder().decode(PixelPolygon.self, from: propertyList as! Data) else { return nil }
        self.init(id: item.id, coordinates: item.coordinates)
        copyFrom(item)
    }
    
    override class func readableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.polygon]
    }
    
    override func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.polygon]
    }
    
}

extension PixelPolygon /*: Equatable*/ {
    
    static func == (lhs: PixelPolygon, rhs: PixelPolygon) -> Bool {
        return lhs.coordinates.elementsEqual(rhs.coordinates)
    }
    
}

extension PixelPolygon /*: CustomStringConvertible*/ {
    
    override var description: String { NSLocalizedString(String(format: "Polygon with %ld coordinates", coordinates.count), comment: "PixelPolygon Description") }
    
    override var debugDescription: String { "<#\(id): \(tags.contents) (\(Int(similarity * 100.0))%); \(coordinates.map({ $0.description }).joined(separator: ","))>" }
    
}

