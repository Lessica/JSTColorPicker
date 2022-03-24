//
//  FieldOption+CoreDataProperties.swift
//  JSTColorPicker
//
//  Created by Darwin on 5/25/20.
//  Copyright © 2020 JST. All rights reserved.
//

import CoreData
import Foundation

extension FieldOption {
    @nonobjc class func fetchRequest() -> NSFetchRequest<FieldOption> {
        return NSFetchRequest<FieldOption>(entityName: "FieldOption")
    }

    @NSManaged var name: String
}
