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
    
    public var id: Int
    public var tags: [String] = []
    
    init(id: Int) {
        self.id = id
    }

    required init?(coder: NSCoder) {
        self.id = coder.decodeInteger(forKey: "id")
        self.tags = (coder.decodeObject(forKey: "tags") as? [String]) ?? []
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(tags, forKey: "tags")
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
    }
    
    func push(_ vm: VirtualMachine) {
        fatalError("push(_:) has not been implemented")
    }
    
    func kind() -> Kind { return .table }
    
    fileprivate static let typeName: String = "content item (table with keys [id,tags])"
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

