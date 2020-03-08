//
//  Annotator.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/8/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

class Annotator {
    public var pixelItem: ContentItem
    public var view: AnnotatorOverlay
    public var rulerMarkers: [RulerMarker] = []
    
    public var isEditable: Bool {
        get { return view.isEditable }
        set { view.isEditable = newValue }
    }
    public var isFixedAnnotator: Bool {
        get { return view.isFixedOverlay }
        set { view.isFixedOverlay = newValue }
    }
    public var isHighlighted: Bool {
        get { return view.isHighlighted }
        set { view.isHighlighted = newValue }
    }
    public var label: String { return view.label }
    public func setNeedsDisplay() {
        view.setNeedsDisplay()
    }
    
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
