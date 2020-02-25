//
//  ContentItem.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/3/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation
import LuaSwift

class ContentItem: NSObject, NSCoding, Comparable, NSCopying, Codable, LuaSwift.Value {
    
    var id: Int
    var similarity: Double = 1.0
    
    init(id: Int) {
        self.id = id
    }
    
    init(id: Int, similarity: Double) {
        self.id = id
        self.similarity = similarity
    }
    
    required init?(coder: NSCoder) {
        self.id = coder.decodeInteger(forKey: "id")
        self.similarity = coder.decodeDouble(forKey: "similarity")
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
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
        return ContentItem(id: id)
    }
    
    func push(_ vm: VirtualMachine) {
        let t = vm.createTable()
        t["id"] = id
        t["similarity"] = Double(self.similarity)
        t.push(vm)
    }
    
    func kind() -> Kind { return .table }
    
    fileprivate static let typeName: String = "content item (table with keys [id,similarity])"
    class func arg(_ vm: VirtualMachine, value: Value) -> String? {
        if value.kind() != .table { return typeName }
        if let result = Table.arg(vm, value: value) { return result }
        let t = value as! Table
        if !(t["id"] is Number) || !(t["similarity"] is Number) { return typeName }
        return nil
    }
}
