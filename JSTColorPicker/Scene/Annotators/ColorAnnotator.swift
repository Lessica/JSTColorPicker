//
//  ColorAnnotator.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/29/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

final class ColorAnnotator: Annotator {
    var pixelColor    : PixelColor            { contentItem as! PixelColor        }
    var pixelOverlay  : ColorAnnotatorOverlay { overlay as! ColorAnnotatorOverlay }
    
    init(_ color: PixelColor) {
        let overlay = ColorAnnotatorOverlay(coordinate: color.coordinate, label: String(color.id))
        super.init(color, overlay)
    }
}

