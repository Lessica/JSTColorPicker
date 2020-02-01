//
//  Content.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/21/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

class Content {
    static let maximumCount = 99
    var items: [PixelColor] = []  // ordered by id asc
    
    init() {
        // default empty init
    }
    required init?(coder: NSCoder) {
        guard let pixelColorCollection = coder.decodeObject(forKey: "pixelColorCollection") as? [PixelColor] else { return nil }
        self.items = pixelColorCollection
    }
}

extension Content: NSCoding {
    func encode(with coder: NSCoder) {
        coder.encode(items, forKey: "pixelColorCollection")
    }
}
