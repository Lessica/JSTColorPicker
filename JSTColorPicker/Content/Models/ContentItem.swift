//
//  ContentItem.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/3/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation
import LuaSwift

class ContentItem: NSObject, NSSecureCoding, NSCopying, LuaSwift.Value, NSPasteboardWriting, NSPasteboardReading, Codable
{
    
    class var supportsSecureCoding: Bool { true }
    
    enum CodingKeys: String, CodingKey {
        case id, tags, similarity
    }
    
    public var id: Int
    public var tags = OrderedSet<String>()
    public var similarity: Double = 1.0
    
    init(id: Int) {
        self.id = id
    }

    required init?(coder: NSCoder) {
        id = coder.decodeInteger(forKey: "id")
        tags = OrderedSet((coder.decodeObject(forKey: "tags") as? [String]) ?? [])
        similarity = coder.decodeDouble(forKey: "similarity")
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        tags = OrderedSet(try container.decode([String].self, forKey: .tags))
        similarity = try container.decode(Double.self, forKey: .similarity)
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(tags.contents, forKey: "tags")
        coder.encode(similarity, forKey: "similarity")
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(tags.contents, forKey: .tags)
        try container.encode(similarity, forKey: .similarity)
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? ContentItem else { return false }
        return self == object
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        fatalError("copy(with:) has not been implemented")
    }
    
    func copyFrom(_ item: ContentItem) {
        id = item.id
        tags = item.tags
        similarity = item.similarity
    }
    
    func push(_ vm: VirtualMachine) {
        fatalError("push(_:) has not been implemented")
    }
    
    func kind() -> Kind { return .table }
    
    private static let typeName: String = "content item (table with keys [id,tags])"
    class func arg(_ vm: VirtualMachine, value: Value) -> String? {
        fatalError("arg(_:value:) has not been implemented")
    }
    
    override var description: String { "<#\(id): \(tags)>" }
    
    
    // MARK: - Pasteboard
    
    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    class func readableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        fatalError("readableTypes(for:) has not been implemented")
    }
    
    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        fatalError("writableTypes(for:) has not been implemented")
    }
    
    static func readingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.ReadingOptions {
        return .asData
    }
    
    func writingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.WritingOptions {
        return .promised
    }
    
    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        return try? PropertyListEncoder().encode(self)
    }
    
}

