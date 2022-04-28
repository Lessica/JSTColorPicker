//
//  RoundedField.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/4.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

final class RoundedField: NSVisualEffectView {
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer!.cornerRadius = 6
        material = .selection
    }
    
}
