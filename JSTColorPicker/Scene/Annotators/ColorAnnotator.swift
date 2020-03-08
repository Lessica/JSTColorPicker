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
        return pixelItem as! PixelColor
    }
    var pixelView: ColorAnnotatorOverlay {
        return view as! ColorAnnotatorOverlay
    }
    
    init(pixelItem: PixelColor) {
        super.init(pixelItem: pixelItem, view: ColorAnnotatorOverlay(label: String(pixelItem.id), coordinate: pixelItem.coordinate))
    }
}

