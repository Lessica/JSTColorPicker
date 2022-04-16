//
//  TagController.swift
//  JSTColorPicker
//
//  Created by Darwin on 5/25/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

final class TagController: NSArrayController {
    
    @objc dynamic var controllerDisplayTitle: String = NSLocalizedString("Tag Manager", comment: "TagController")
    
    override var isEditable: Bool {
        get {
            super.isEditable
        }
        set {
            super.isEditable = newValue
            if newValue {
                controllerDisplayTitle = NSLocalizedString("Tag Manager", comment: "TagController")
            } else {
                controllerDisplayTitle = NSLocalizedString("Tag Manager (Read-only)", comment: "TagController")
            }
        }
    }
    
    override func insert(_ object: Any, atArrangedObjectIndex index: Int) {
        guard let items = arrangedObjects as? [Tag] else { return }
        if let tag = object as? Tag {
            tag.colorHex = NSColor.random.sharpCSS
            let untitledNames: [String] = items.compactMap({ $0.name }).lazy
                .filter({ $0.hasPrefix("Untitled #") })
            let sortedUntitledNames: [String] = untitledNames
                .sorted(by: { $0.localizedStandardCompare($1) == .orderedDescending })
            let origChar: String = String(sortedUntitledNames.first?.dropFirst(10) ?? "0")
            let replChar = String((Int(String(origChar)) ?? 0) + 1)
            tag.name = "Untitled #\(replChar)"
        }
        super.insert(object, atArrangedObjectIndex: index)
    }
    
}
