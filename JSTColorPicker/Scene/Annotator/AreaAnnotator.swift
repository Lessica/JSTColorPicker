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
    var pixelView: AreaAnnotatorOverlay {
        return view as! AreaAnnotatorOverlay
    }
    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                pixelView.isAnimating = true
            } else {
                pixelView.isAnimating = false
            }
        }
    }
    
    init(pixelItem: PixelArea) {
        super.init(pixelItem: pixelItem, view: AreaAnnotatorOverlay(label: String(pixelItem.id)))
    }
}
