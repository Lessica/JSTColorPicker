//
//  ShortcutGuideDataSource.swift
//  JSTColorPicker
//
//  Created by Darwin on 2021/3/27.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

protocol ShortcutGuideDataSource: NSResponder {
    var shortcutItems: [ShortcutItem] { get }
}
