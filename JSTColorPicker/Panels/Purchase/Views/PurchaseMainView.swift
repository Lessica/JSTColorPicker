//
//  PurchaseMainView.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/23.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

final class PurchaseMainView: NSVisualEffectView {
    
    override var mouseDownCanMoveWindow: Bool { true }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        material = .hudWindow
    }
    
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
    
}
