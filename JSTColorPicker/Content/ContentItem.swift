//
//  ContentItem.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/3/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

class ContentItem: NSObject, NSCoding, Comparable, NSCopying {
    var id: Int
    var similarity: Double = 1.0
    
    init(id: Int) {
        self.id = id
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
    
//    static func == (lhs: ContentItem, rhs: ContentItem) -> Bool {
//        return lhs.id == rhs.id
//    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        return ContentItem(id: id)
    }
}
