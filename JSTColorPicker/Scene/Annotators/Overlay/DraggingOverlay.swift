//
//  DraggingOverlay.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/4/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class DraggingOverlay: Overlay {
    public var contextRect    : PixelRect?
    override var borderStyle  : BorderStyle { .dashed }
}
