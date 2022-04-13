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
        case name, options, defaultValue, valueType, helpText
    }

    enum StringValueType: String, Codable {
        case String // text input
        case Boolean // checkbox
        case Integer // text input
        case Decimal // text input
        case Nil // nothing
    }

    internal var stringValueType: StringValueType? {
        if let valueType = valueType {
            return StringValueType(rawValue: valueType)
        }
        return nil
    }

    internal func toDefaultValue(ofType type: Bool.Type) -> Bool? {
        if let rawValue = defaultValue {
            return !(rawValue.hasPrefix("f") || rawValue.hasPrefix("n") || rawValue.hasPrefix("0"))
        }
        return nil
    }

    internal func toDefaultValue<T>(ofType type: T.Type) -> T? where T: FixedWidthInteger {
        if let rawValue = defaultValue {
            return T(rawValue)
        }
        return nil
    }

    internal func toDefaultValue(ofType type: Double.Type) -> Double? {
        if let rawValue = defaultValue {
            return Double(rawValue)
        }
        return nil
    }

    internal func toDefaultValue<T>(ofType type: T.Type) -> T? where T: StringProtocol {
        return defaultValue as? T
    }

    public required convenience init(from decoder: Decoder) throws {
        guard let context = decoder.userInfo[CodingUserInfoKey.managedObjectContext] as? NSManagedObjectContext else {
            throw DecoderConfigurationError.missingManagedObjectContext
        }

        self.init(context: context)

        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        defaultValue = try container.decodeIfPresent(String.self, forKey: .defaultValue)
        valueType = try container.decodeIfPresent(String.self, forKey: .valueType)
        helpText = try container.decodeIfPresent(String.self, forKey: .helpText)
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
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(defaultValue, forKey: .defaultValue)
        try container.encodeIfPresent(valueType, forKey: .valueType)
        try container.encodeIfPresent(helpText, forKey: .helpText)
        try container.encode(options.array as? [FieldOption] ?? [], forKey: .options)
    }
}
