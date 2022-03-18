//
//  Field+CoreDataClass.swift
//  JSTColorPicker
//
//  Created by Darwin on 3/18/22.
//  Copyright © 2020 JST. All rights reserved.
//

import CoreData
import Foundation

extension CodingUserInfoKey {
    static let managedObjectContext = CodingUserInfoKey(rawValue: "managedObjectContext")!
}

enum DecoderConfigurationError: Error {
    case missingManagedObjectContext
}

@objc(Field)
final class Field: NSManagedObject, Codable {
    enum CodingKeys: CodingKey {
        case helpText, name, order, type, validationRegex
    }
    
    private static var initializedOrder: Int64 = 0

    required convenience init(from decoder: Decoder) throws {
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
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(helpText, forKey: .helpText)
        try container.encode(name, forKey: .name)
        try container.encode(order, forKey: .order)
        try container.encode(type, forKey: .type)
        try container.encode(validationRegex, forKey: .validationRegex)
    }
}
