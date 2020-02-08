//
//  Annotator.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/8/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

class Annotator {
    
    var pixelItem: ContentItem
    var view: NSView
    var isHighlighted: Bool = false
    var label: String = "0"
    
    init(pixelItem: ContentItem, view: NSView) {
        self.pixelItem = pixelItem
        self.view = view
    }
    
}
