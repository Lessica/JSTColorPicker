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

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Tag> {
        return NSFetchRequest<Tag>(entityName: "Tag")
    }

    @NSManaged public var colorHex: String
    @NSManaged public var name: String
    @NSManaged public var order: Int64
    
    @objc public var color: NSColor { NSColor(hex: colorHex) }
    @objc public var toolTip: String { name + " (" + colorHex + ")" }
    
    @objc public func colorWithAlphaComponent(_ alpha: CGFloat) -> NSColor {
        return NSColor(hex: colorHex, alpha: alpha)
    }

}
