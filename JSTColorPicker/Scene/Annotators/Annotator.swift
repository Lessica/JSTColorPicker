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

    public var isEditable    : Bool
    {
        get { overlay.isEditable                 }
        set { overlay.isEditable = newValue      }
    }
    
    public var isSelected    : Bool
    {
        get { overlay.isSelected                 }
        set { overlay.isSelected = newValue      }
    }

    public var revealStyle   : AnnotatorOverlay.RevealStyle
    {
        get { overlay.revealStyle                }
        set { overlay.revealStyle = newValue     }
    }
    
    init(_ item: ContentItem, _ overlay: AnnotatorOverlay) {
        self.contentItem = item
        self.overlay = overlay
    }
    
}

extension Annotator: CustomStringConvertible {
    var description: String { "[Annotator \(contentItem), isSelected = \(isSelected)]" }
}
