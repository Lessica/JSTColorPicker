//
//  LabelBgView.swift
//  JSTColorPicker
//
//  Created by Darwin on 2020/12/2.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class LabelBgView: NSView {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = true
        layer?.isOpaque = true
        layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.5).cgColor
        layer?.cornerRadius = 5.0
    }
    
}

