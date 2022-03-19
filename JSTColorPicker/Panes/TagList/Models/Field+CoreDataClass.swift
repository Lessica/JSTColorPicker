//
//  Field+CoreDataClass.swift
//  JSTColorPicker
//
//  Created by Darwin on 3/18/22.
//  Copyright © 2020 JST. All rights reserved.
//

import CoreData
import Foundation

@objc(Field)
public final class Field: NSManagedObject, Codable {
    enum CodingKeys: CodingKey {
        case helpText, name, order, type, validationRegex, options
    }
    
    private static var initializedOrder: Int64 = 0

    required convenience public init(from decoder: Decoder) throws {
        guard let context = decoder.userInfo[CodingUserInfoKey.managedObjectContext] as? NSManagedObjectContext else {
            throw DecoderConfigurationError.missingManagedObjectContext
        }

        self.init(context: context)

        let container = try decoder.container(keyedBy: CodingKeys.self)
        helpText = try container.decodeIfPresent(String.self, forKey: .helpText)
        name = try container.decode(String.self, forKey: .name)
        Field.initializedOrder += 1
        order = try container.decodeIfPresent(Int64.self, forKey: .order) ?? Field.initializedOrder
        type = try container.decode(String.self, forKey: .type)
        validationRegex = try container.decodeIfPresent(String.self, forKey: .validationRegex)
        do {
            let possibleOptionNames = try container.decodeIfPresent([String].self, forKey: .options) ?? []
            let possibleOptions = possibleOptionNames.compactMap { optionName -> FieldOption in
                let option = FieldOption(context: context)
                option.name = optionName
                return option
            }
            options = NSOrderedSet(array: possibleOptions)
        } catch {
            options = NSOrderedSet(array: try container.decodeIfPresent([FieldOption].self, forKey: .options) ?? [])
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(helpText, forKey: .helpText)
        try container.encode(name, forKey: .name)
        try container.encode(order, forKey: .order)
        try container.encode(type, forKey: .type)
        try container.encode(validationRegex, forKey: .validationRegex)
        try container.encode(options.array as? [FieldOption] ?? [], forKey: .options)
    }
}
