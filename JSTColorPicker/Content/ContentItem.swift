//
//  ContentItem.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/3/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation
import LuaSwift

extension NSPasteboard.PasteboardType {
    static let content = NSPasteboard.PasteboardType(rawValue: "com.jst.content")
}

class ContentItem: NSObject, NSSecureCoding, Comparable, NSCopying, Codable, LuaSwift.Value, NSPasteboardWriting, NSPasteboardReading {
    class var supportsSecureCoding: Bool {
        return true
    }
    
    var id: Int
    var delay: Double = 1.0
    var similarity: Double = 1.0
    
    init(id: Int) {
        self.id = id
    }
    
    init(id: Int, delay: Double, similarity: Double) {
        self.id = id
        self.delay = delay
        self.similarity = similarity
    }

    required init?(coder: NSCoder) {
        self.id = coder.decodeInteger(forKey: "id")
        self.delay = coder.decodeDouble(forKey: "delay")
        self.similarity = coder.decodeDouble(forKey: "similarity")
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(delay, forKey: "delay")
        coder.encode(similarity, forKey: "similarity")
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? ContentItem else { return false }
        return self == object
    }
    
    static func < (lhs: ContentItem, rhs: ContentItem) -> Bool {
        return lhs.id < rhs.id
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        return ContentItem(id: id, delay: delay, similarity: similarity)
    }
    
    func push(_ vm: VirtualMachine) {
        let t = vm.createTable()
        t["id"] = id
        t["delay"] = Double(delay)
        t["similarity"] = Double(similarity)
        t.push(vm)
    }
    
    func kind() -> Kind { return .table }
    
    fileprivate static let typeName: String = "content item (table with keys [id,similarity,delay])"
    class func arg(_ vm: VirtualMachine, value: Value) -> String? {
        if value.kind() != .table { return typeName }
        if let result = Table.arg(vm, value: value) { return result }
        let t = value as! Table
        if !(t["id"] is Number) ||
            !(t["delay"] is Number) ||
            !(t["similarity"] is Number)
        {
            return typeName
        }
        return nil
    }
    
    override var description: String {
        return "(ID: \(id))"
    }
    
    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.content]
    }
    
    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        return NSKeyedArchiver.archivedData(withRootObject: self)
    }
    
    static func readableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.content]
    }
    
    static func readingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.ReadingOptions {
        return .asKeyedArchive
    }
    
    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
}
