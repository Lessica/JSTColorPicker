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

    @NSManaged @objc var helpText: String?
    @NSManaged var colorHex: String
    @NSManaged var name: String
    @NSManaged var order: Int64
    @NSManaged var fields: NSOrderedSet
}
