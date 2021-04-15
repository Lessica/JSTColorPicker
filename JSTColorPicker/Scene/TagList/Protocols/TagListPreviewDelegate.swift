//
//  TagListPreviewDelegate.swift
//  JSTColorPicker
//
//  Created by Darwin on 6/24/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol TagListPreviewDelegate: class {
    func previewTags(for items: [ContentItem])
}
