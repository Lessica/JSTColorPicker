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
    
    var pixelView: AreaAnnotatorOverlay {
        return overlay as! AreaAnnotatorOverlay
    }
    
    init(pixelItem: PixelArea) {
        super.init(pixelItem: pixelItem, view: AreaAnnotatorOverlay(label: String(pixelItem.id), rect: pixelItem.rect))
    }
    
}
