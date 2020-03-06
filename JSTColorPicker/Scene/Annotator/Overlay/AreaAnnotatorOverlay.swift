//
//  AreaAnnotatorOverlay.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/8/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class AreaAnnotatorOverlay: AnnotatorOverlay {
    
    override init(label: String) {
        super.init(label: label)
        backgroundImage = #imageLiteral(resourceName: "Annotator")
        highlightedBackgroundImage = #imageLiteral(resourceName: "AnnotatorBlue")
        focusedBackgroundImage = #imageLiteral(resourceName: "AnnotatorBlueFocused")
        focusedTextColor = NSColor(srgbRed: 0.1176, green: 0.2157, blue: 0.6, alpha: 1.0)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
