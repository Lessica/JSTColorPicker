//
//  Annotator.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/8/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

class Annotator {
    
    public var contentItem: ContentItem
    public var overlay: AnnotatorOverlay
    public var rulerMarkers: [RulerMarker] = []
    
    public var isEditable: Bool {
        get { return overlay.isEditable }
        set { overlay.isEditable = newValue }
    }
    
    public var isFixedAnnotator: Bool {
        get { return overlay.isFixedOverlay }
        set { overlay.isFixedOverlay = newValue }
    }
    
    public var isSelected: Bool {
        get { return overlay.isSelected }
        set { overlay.isSelected = newValue }
    }
    
    public var label: String { return overlay.label }
    
    init(_ item: ContentItem, _ overlay: AnnotatorOverlay) {
        self.contentItem = item
        self.overlay = overlay
    }
    
}

extension Annotator: CustomStringConvertible {
    
    var description: String {
        return "[Annotator \(contentItem), isSelected = \(isSelected)]"
    }
    
}
