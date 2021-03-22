//
//  AreaAnnotator.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/8/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

class AreaAnnotator: Annotator {
    public var pixelArea     : PixelArea            { contentItem as! PixelArea        }
    public var pixelOverlay  : AreaAnnotatorOverlay { overlay as! AreaAnnotatorOverlay }
    
    init(_ area: PixelArea) {
        let overlay = AreaAnnotatorOverlay(rect: area.rect, label: String(area.id), associatedLabel: area.tags.first)
        super.init(area, overlay)
    }
}

