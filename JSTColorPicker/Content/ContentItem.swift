//
//  ContentItem.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/3/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

class ContentItem: NSObject, NSCoding, Comparable {
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
    
    static func < (lhs: ContentItem, rhs: ContentItem) -> Bool {
        return lhs.id < rhs.id
    }
}
