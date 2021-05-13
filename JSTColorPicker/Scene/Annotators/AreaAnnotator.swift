//
//  AreaAnnotator.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/8/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

final class AreaAnnotator: Annotator {
    var pixelArea     : PixelArea            { contentItem as! PixelArea        }
    var pixelOverlay  : AreaAnnotatorOverlay { overlay as! AreaAnnotatorOverlay }
    
    init(_ area: PixelArea) {
        let overlay = AreaAnnotatorOverlay(rect: area.rect, label: String(area.id), associatedLabel: area.firstTag)
        super.init(area, overlay)
    }
}

