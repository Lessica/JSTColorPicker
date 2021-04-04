//
//  AreaAnnotatorOverlay.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/8/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class AreaAnnotatorOverlay: AnnotatorOverlay {

    internal private(set) var rect: PixelRect
    override var hidesDuringEditing: Bool { true }

    init(rect: PixelRect, label: String, associatedLabel: String? = nil) {
        self.rect = rect
        super.init(label: label, associatedLabel: associatedLabel)

        backgroundImage            = NSImage(named: "Annotator")!
        selectedBackgroundImage = NSImage(named: "AnnotatorBlue")!
        focusedBackgroundImage     = NSImage(named: "AnnotatorBlueFocused")!
        focusedLabelColor           = NSColor(srgbRed: 0.1176, green: 0.2157, blue: 0.6, alpha: 1.0)
        revealStyle                = .none
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
