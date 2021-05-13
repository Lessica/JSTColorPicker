//
//  TagController.swift
//  JSTColorPicker
//
//  Created by Darwin on 5/25/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

final class TagController: NSArrayController {
    
    override func insert(_ object: Any, atArrangedObjectIndex index: Int) {
        guard let items = arrangedObjects as? [Tag] else { return }
        if let tag = object as? Tag {
            tag.colorHex = NSColor.random.sharpCSS
            let origChar = items
                .compactMap({ $0.name }).lazy
                .filter({ $0.hasPrefix("Untitled #") })
                .sorted(by: { $0.localizedStandardCompare($1) == .orderedDescending })
                .first?
                .dropFirst(10)
                ?? "0"
            let replChar = String((Int(String(origChar)) ?? 0) + 1)
            tag.name = "Untitled #\(replChar)"
        }
        super.insert(object, atArrangedObjectIndex: index)
    }
    
}
