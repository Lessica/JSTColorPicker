//
//  ContentCellView.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/6/15.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class ContentCellView: NSTableCellView {
    
    public var normalTextColor: NSColor? {
        didSet {
            updateTextColor()
        }
    }
    
    public var text: String? {
        get { textField?.stringValue }
        set { textField?.stringValue = newValue ?? "" }
    }
    
    public var image: NSImage? {
        get { imageView?.image }
        set { imageView?.image = newValue }
    }

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            updateTextColor()
        }
    }
    
    private func updateTextColor() {
        if backgroundStyle == .emphasized {
            textField?.textColor = .white
        } else {
            textField?.textColor = normalTextColor
        }
    }
    
}
