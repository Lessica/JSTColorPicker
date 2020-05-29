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
    static let content = NSPasteboard.PasteboardType(rawValue: "public.jst.content")
}

class ContentItem: NSObject, NSSecureCoding, NSCopying, Codable, LuaSwift.Value, NSPasteboardWriting, NSPasteboardReading {
    class var supportsSecureCoding: Bool {
        return true
    }
    
    var id: Int
    
    init(id: Int) {
        self.id = id
    }

    required init?(coder: NSCoder) {
        self.id = coder.decodeInteger(forKey: "id")
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? ContentItem else { return false }
        return self == object
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        return ContentItem(id: id)
    }
    
    func push(_ vm: VirtualMachine) {
        let t = vm.createTable()
        t["id"] = id
        t.push(vm)
    }
    
    func kind() -> Kind { return .table }
    
    fileprivate static let typeName: String = "content item (table with keys [id])"
    class func arg(_ vm: VirtualMachine, value: Value) -> String? {
        if value.kind() != .table { return typeName }
        if let result = Table.arg(vm, value: value) { return result }
        let t = value as! Table
        if !(t["id"] is Number)
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
