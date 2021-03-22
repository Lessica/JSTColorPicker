//
//  ColorAnnotatorOverlay.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/31/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class ColorAnnotatorOverlay: AnnotatorOverlay {
    
    public private(set) var coordinate: PixelCoordinate
    
    init(coordinate: PixelCoordinate, label: String) {
        self.coordinate = coordinate
        super.init(label: label)

        backgroundImage            = NSImage(named: "Annotator")!
        selectedBackgroundImage = NSImage(named: "AnnotatorRed")!
        focusedBackgroundImage     = NSImage(named: "AnnotatorRedFocused")!
        focusedLabelColor           = NSColor(srgbRed: 0.9098, green: 0.2549, blue: 0.0941, alpha: 1.0)
        revealStyle                = .fixed
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
