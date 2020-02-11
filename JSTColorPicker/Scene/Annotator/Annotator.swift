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
    var view: AnnotatorOverlay
    var rulerMarkers: [RulerMarker] = []
    var isHighlighted: Bool = false
    var label: String = "0"
    
    init(pixelItem: ContentItem, view: AnnotatorOverlay) {
        self.pixelItem = pixelItem
        self.view = view
    }
    
}

extension Annotator: CustomStringConvertible {
    var description: String {
        return "[Annotator \(pixelItem), isHighlighted = \(isHighlighted)]"
    }
}
