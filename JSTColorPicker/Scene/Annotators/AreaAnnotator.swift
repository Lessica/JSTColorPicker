//
//  AreaAnnotator.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/8/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

class AreaAnnotator: Annotator {
    
    var pixelArea: PixelArea {
        return contentItem as! PixelArea
    }
    
    var pixelOverlay: AreaAnnotatorOverlay {
        return overlay as! AreaAnnotatorOverlay
    }
    
    init(_ area: PixelArea) {
        let overlay = AreaAnnotatorOverlay(label: String(area.id), rect: area.rect)
        super.init(area, overlay)
    }
    
}

