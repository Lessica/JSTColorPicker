//
//  SceneAnnotator.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/29/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

class SceneAnnotator {
    
    var pixelColor: PixelColor
    var view: SceneAnnotatorView
    
    init(pixelColor: PixelColor) {
        let view = SceneAnnotatorView()
        view.wantsLayer = true
        view.layer?.backgroundColor = .black
        // setup view
        self.pixelColor = pixelColor
        self.view = view
    }
    
}

