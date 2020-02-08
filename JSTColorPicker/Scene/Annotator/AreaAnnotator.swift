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
        return pixelItem as! PixelArea
    }
    var pixelView: AreaAnnotatorView {
        return view as! AreaAnnotatorView
    }
    
    init(pixelItem: PixelArea) {
        super.init(pixelItem: pixelItem, view: AreaAnnotatorView())
    }
    
}
