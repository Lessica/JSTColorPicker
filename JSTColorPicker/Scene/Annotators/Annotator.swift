//
//  Annotator.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/8/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

class Annotator {
    
    var contentItem   : ContentItem
    var overlay       : AnnotatorOverlay
    var rulerMarkers  : [RulerMarker] = []
    var label         : String { overlay.label }

    var isEditable    : Bool
    {
        get { overlay.isEditable                 }
        set { overlay.isEditable = newValue      }
    }
    
    var isSelected    : Bool
    {
        get { overlay.isSelected                 }
        set { overlay.isSelected = newValue      }
    }

    var revealStyle   : AnnotatorOverlay.RevealStyle
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
