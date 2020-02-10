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
    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                pixelView.backgroundCell.stringValue = "🔴"
                pixelView.labelCell.textColor = .white
            } else {
                pixelView.backgroundCell.stringValue = "⚪️"
                pixelView.labelCell.textColor = .black
            }
        }
    }
    override var label: String {
        didSet {
            pixelView.labelCell.stringValue = label
        }
    }
    
    init(pixelItem: PixelColor) {
        let view = ColorAnnotatorOverlay()
        view.backgroundCell.stringValue = "⚪️"
        view.labelCell.stringValue = String(pixelItem.id)
        view.labelCell.textColor = .black
        view.isSmallArea = true
        super.init(pixelItem: pixelItem, view: view)
    }
    
}

