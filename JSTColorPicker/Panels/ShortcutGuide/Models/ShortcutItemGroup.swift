//
//  ShortcutItemGroup.swift
//  JSTColorPicker
//
//  Created by Darwin on 2021/3/25.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

internal struct ShortcutItemGroup {
    let identifier: String?
    let items: [ShortcutItem]

    static func splitItemsIntoGroups(_ items: [ShortcutItem], maximumCount max: Int) -> [ShortcutItemGroup]
    {
        var cnt = 0
        return items.chunked(into: max).map {
            cnt += 1
            return ShortcutItemGroup(identifier: "group-\(cnt)", items: $0)
        }
    }

    static let empty = ShortcutItemGroup(identifier: "empty", items: [])
}
