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
                pixelView.backgroundCell.stringValue = "🔵"
                pixelView.labelCell.textColor = .white
                pixelView.isAnimating = true
            } else {
                pixelView.backgroundCell.stringValue = "⚪️"
                pixelView.labelCell.textColor = .black
                pixelView.isAnimating = false
            }
        }
    }
    override var label: String {
        didSet {
            pixelView.labelCell.stringValue = label
        }
    }
    
    init(pixelItem: PixelArea) {
        let view = AreaAnnotatorOverlay()
        view.backgroundCell.stringValue = "⚪️"
        view.labelCell.stringValue = String(pixelItem.id)
        view.labelCell.textColor = .black
        super.init(pixelItem: pixelItem, view: view)
    }
    
}
