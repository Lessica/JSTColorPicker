//
//  Annotator.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/8/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

class Annotator {
    
    public var contentItem   : ContentItem
    public var overlay       : AnnotatorOverlay
    public var rulerMarkers  : [RulerMarker] = []
    public var label         : String { overlay.label }
    
    public var isEditing: Bool
    {
        get { overlay.isEditing                 }
        set { overlay.isEditing = newValue      }
    }
    
    public var isFixedAnnotator: Bool
    {
        get { overlay.isFixedOverlay            }
        set { overlay.isFixedOverlay = newValue }
    }
    
    public var isSelected: Bool
    {
        get { overlay.isSelected                }
        set { overlay.isSelected = newValue     }
    }
    
    init(_ item: ContentItem, _ overlay: AnnotatorOverlay) {
        self.contentItem = item
        self.overlay = overlay
    }
    
}

extension Annotator: CustomStringConvertible {
    var description: String { "[Annotator \(contentItem), isSelected = \(isSelected)]" }
}
