//
//  ItemInspector.swift
//  JSTColorPicker
//
//  Created by Darwin on 6/24/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol ItemInspector: AnyObject {
    func inspectItem(_ item: ContentItem)
}
