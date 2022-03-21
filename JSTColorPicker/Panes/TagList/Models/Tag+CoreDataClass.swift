//
//  Tag+CoreDataClass.swift
//  JSTColorPicker
//
//  Created by Darwin on 5/25/20.
//  Copyright © 2020 JST. All rights reserved.
//

import CoreData
import Foundation

@objc(Tag)
public final class Tag: NSManagedObject, Codable {
    enum CodingKeys: CodingKey {
        case helpText, colorHex, name, order, fields
    }
    
    private static var initializedOrder: Int64 = 0

    required convenience public init(from decoder: Decoder) throws {
        guard let context = decoder.userInfo[CodingUserInfoKey.managedObjectContext] as? NSManagedObjectContext else {
            throw DecoderConfigurationError.missingManagedObjectContext
        }

        self.init(context: context)

        let container = try decoder.container(keyedBy: CodingKeys.self)
        helpText = try container.decodeIfPresent(String.self, forKey: .helpText)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        name = try container.decode(String.self, forKey: .name)
        Tag.initializedOrder += 1
        order = try container.decodeIfPresent(Int64.self, forKey: .order) ?? Tag.initializedOrder
        fields = NSOrderedSet(array: try container.decodeIfPresent([Field].self, forKey: .fields) ?? [])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(helpText, forKey: .helpText)
        try container.encode(colorHex, forKey: .colorHex)
        try container.encode(name, forKey: .name)
        try container.encode(order, forKey: .order)
        try container.encode(fields.array as? [Field] ?? [], forKey: .fields)
    }
    
    @objc var color: NSColor { NSColor(hex: colorHex) }
    @objc var toolTip: String {
        if let helpText = helpText, !helpText.isEmpty {
            return String(format: "%@ (%@)\n%@", name, colorHex, helpText)
        }
        return String(format: "%@ (%@)", name, colorHex)
    }

    @objc func colorWithAlphaComponent(_ alpha: CGFloat) -> NSColor {
        return NSColor(hex: colorHex, alpha: alpha)
    }
}
