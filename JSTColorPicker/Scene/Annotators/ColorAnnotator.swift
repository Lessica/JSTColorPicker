//
//  ColorAnnotator.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/29/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

class ColorAnnotator: Annotator {
    
    var pixelColor: PixelColor {
        return contentItem as! PixelColor
    }
    
    var pixelOverlay: ColorAnnotatorOverlay {
        return overlay as! ColorAnnotatorOverlay
    }
    
    init(_ color: PixelColor) {
        let overlay = ColorAnnotatorOverlay(label: String(color.id), coordinate: color.coordinate)
        super.init(color, overlay)
    }
    
}

