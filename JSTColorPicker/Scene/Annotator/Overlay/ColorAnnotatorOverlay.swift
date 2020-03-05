//
//  ColorAnnotatorOverlay.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/31/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class ColorAnnotatorOverlay: AnnotatorOverlay {
    
    override init(label: String) {
        super.init(label: label)
        isSmallOverlay = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
