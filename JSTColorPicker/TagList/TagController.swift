//
//  TagController.swift
//  JSTColorPicker
//
//  Created by Darwin on 5/25/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class TagController: NSArrayController {
    
    override func insert(_ object: Any, atArrangedObjectIndex index: Int) {
        if let tag = object as? Tag {
            tag.colorHex = NSColor.random.sharpCSS
        }
        super.insert(object, atArrangedObjectIndex: index)
    }
    
}
