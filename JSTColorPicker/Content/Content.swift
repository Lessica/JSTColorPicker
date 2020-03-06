//
//  Content.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/21/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

class Content: NSObject {
    public var items: [ContentItem] = []  // ordered by id asc
    public var lazyColors: [PixelColor] {
        return items.lazy.compactMap({ $0 as? PixelColor })
    }
    public var lazyAreas: [PixelArea] {
        return items.lazy.compactMap({ $0 as? PixelArea })
    }
    
    override init() {
        super.init()
        // default empty init
    }
    required init?(coder: NSCoder) {
        guard let items = coder.decodeObject(forKey: "items") as? [ContentItem] else { return nil }
        self.items = items
    }
}

extension Content: NSCoding {
    func encode(with coder: NSCoder) {
        coder.encode(items, forKey: "items")
    }
}
