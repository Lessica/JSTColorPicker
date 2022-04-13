//
//  ContentItem.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/3/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation
import OrderedCollections
#if WITH_COCOA
import Cocoa

extension ContentItem: NSPasteboardWriting, NSPasteboardReading {}
#endif
#if WITH_LUASWIFT
import LuaSwift

extension ContentItem: LuaSwift.Value {}
#endif

class ContentItem: NSObject, NSSecureCoding, NSCopying, Codable
{
    
    class var supportsSecureCoding: Bool { true }
    
    enum CodingKeys: String, CodingKey {
        case id, tags, similarity, userInfo
        case userInfoKeys, userInfoValues
    }
    
    var id: Int
    var tags: OrderedSet<String> = OrderedSet<String>()
    var firstTag: String? { tags.first }
    var similarity: Double = 1.0
    var userInfo: OrderedDictionary<String, String>?
    var userInfoDict: [String: String]? {
        userInfo?.elements.reduce(into: [String: String](), { (partialResult, partialTuple) in
            partialResult[partialTuple.key] = partialTuple.value
        })
    }
    
    init(id: Int) {
        self.id = id
    }

    required init?(coder: NSCoder) {
        id = coder.decodeInteger(forKey: CodingKeys.id.rawValue)
        tags = OrderedSet((coder.decodeObject(forKey: CodingKeys.tags.rawValue) as? [String]) ?? [])
        similarity = coder.decodeDouble(forKey: CodingKeys.similarity.rawValue)
        if let dictUserInfo = coder.decodeObject(of: NSDictionary.self, forKey: CodingKeys.userInfo.rawValue) as? [String: String]
        {
            var orderedUserInfo: OrderedDictionary<String, String> = [:]
            for (dictKey, dictVal) in dictUserInfo.sorted(by: { $0.key.localizedCompare($1.key) == .orderedAscending })
            {
                orderedUserInfo[dictKey] = dictVal
            }
            userInfo = orderedUserInfo
        } else {
            if let userInfoKeys = coder.decodeObject(of: NSArray.self, forKey: CodingKeys.userInfoKeys.rawValue) as? [String],
               let userInfoVals = coder.decodeObject(of: NSArray.self, forKey: CodingKeys.userInfoValues.rawValue) as? [String],
               userInfoKeys.count == userInfoVals.count
            {
                userInfo = OrderedDictionary(uniqueKeys: userInfoKeys, values: userInfoVals)
            }
        }
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        tags = OrderedSet(try container.decode([String].self, forKey: .tags))
        similarity = try container.decode(Double.self, forKey: .similarity)
        if let dictUserInfo = try container.decodeIfPresent([String: String].self, forKey: .userInfo) {
            var orderedUserInfo: OrderedDictionary<String, String> = [:]
            for (dictKey, dictVal) in dictUserInfo.sorted(by: { $0.key.localizedCompare($1.key) == .orderedAscending })
            {
                orderedUserInfo[dictKey] = dictVal
            }
            userInfo = orderedUserInfo
        } else {
            userInfo = try container.decodeIfPresent(OrderedDictionary<String, String>.self, forKey: .userInfo)
        }
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(id, forKey: CodingKeys.id.rawValue)
        coder.encode(tags.elements, forKey: CodingKeys.tags.rawValue)
        coder.encode(similarity, forKey: CodingKeys.similarity.rawValue)
        if let userInfo = userInfo {
            coder.encode(userInfo.keys.elements, forKey: CodingKeys.userInfoKeys.rawValue)
            coder.encode(userInfo.values.elements, forKey: CodingKeys.userInfoValues.rawValue)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(tags.elements, forKey: .tags)
        try container.encode(similarity, forKey: .similarity)
        try container.encodeIfPresent(userInfo, forKey: .userInfo)
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? ContentItem else { return false }
        return self == object
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        fatalError("copy(with:) has not been implemented")
    }

    func offsetBy(_ offsetPoint: CGPoint) -> Any {
        fatalError("offsetBy(_:) has not been implemented")
    }
    
    func copyFrom(_ item: ContentItem) {
        id = item.id
        tags = item.tags
        similarity = item.similarity
        userInfo = item.userInfo
    }
    
    func userInfoValue(forKey key: String, ofType type: Bool.Type) -> Bool? {
        if let rawValue = userInfo?[key]?.lowercased() {
            return !(rawValue.hasPrefix("f") || rawValue.hasPrefix("n") || rawValue.hasPrefix("0"))
        }
        return nil
    }
    
    func userInfoValue<T>(forKey key: String, ofType type: T.Type) -> T? where T: FixedWidthInteger {
        if let rawValue = userInfo?[key] {
            return T(rawValue)
        }
        return nil
    }
    
    func userInfoValue(forKey key: String, ofType type: Double.Type) -> Double? {
        if let rawValue = userInfo?[key] {
            return Double(rawValue)
        }
        return nil
    }
    
    func userInfoValue<T>(forKey key: String, ofType type: T.Type) -> T? where T: StringProtocol {
        return userInfo?[key] as? T
    }
    
    
    // MARK: - LuaSwift.Value
    
#if WITH_LUASWIFT
    func push(_ vm: VirtualMachine) {
        fatalError("push(_:) has not been implemented")
    }
    
    func kind() -> Kind { return .table }
    
    private static let typeName: String = "content item (table with keys [id,tags])"
    class func arg(_ vm: VirtualMachine, value: Value) -> String? {
        fatalError("arg(_:value:) has not been implemented")
    }
    
    override var description: String { "<#\(id): \(tags)>" }
#endif
    
    
    // MARK: - Pasteboard
    
#if WITH_COCOA
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
#endif
    
}

