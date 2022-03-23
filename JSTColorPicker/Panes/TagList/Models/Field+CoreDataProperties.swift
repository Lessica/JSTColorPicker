//
//  Field+CoreDataProperties.swift
//  JSTColorPicker
//
//  Created by Darwin on 5/25/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation
import CoreData

extension Field {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Field> {
        return NSFetchRequest<Field>(entityName: "Field")
    }

    @NSManaged var name: String
    @NSManaged var defaultValue: String?
    @NSManaged var valueType: String?
    @NSManaged var helpText: String?
    @NSManaged var options: NSOrderedSet
}
