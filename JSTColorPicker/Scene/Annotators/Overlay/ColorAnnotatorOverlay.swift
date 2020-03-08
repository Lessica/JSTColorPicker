//
//  ColorAnnotatorOverlay.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/31/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class ColorAnnotatorOverlay: AnnotatorOverlay {
    
    public fileprivate(set) var coordinate: PixelCoordinate
    
    init(label: String, coordinate: PixelCoordinate) {
        self.coordinate = coordinate
        super.init(label: label)
        isFixedOverlay = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
