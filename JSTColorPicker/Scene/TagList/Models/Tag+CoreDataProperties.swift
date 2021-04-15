//
//  Tag+CoreDataProperties.swift
//  JSTColorPicker
//
//  Created by Darwin on 5/25/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation
import CoreData

extension Tag {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Tag> {
        return NSFetchRequest<Tag>(entityName: "Tag")
    }

    @NSManaged var colorHex: String
    @NSManaged var name: String
    @NSManaged var order: Int64
    
    @objc var color: NSColor { NSColor(hex: colorHex) }
    @objc var toolTip: String { name + " (" + colorHex + ")" }
    
    @objc func colorWithAlphaComponent(_ alpha: CGFloat) -> NSColor {
        return NSColor(hex: colorHex, alpha: alpha)
    }
}
