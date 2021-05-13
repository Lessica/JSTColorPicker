//
//  ContentCellView.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/6/15.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

final class ContentCellView: NSTableCellView {
    
    var normalTextColor: NSColor? {
        didSet {
            updateTextColor()
        }
    }
    
    var text: String? {
        get { textField?.stringValue                  }
        set { textField?.stringValue = newValue ?? "" }
    }
    
    var image: NSImage? {
        get { imageView?.image            }
        set { imageView?.image = newValue }
    }
    
    var allowsExpansionToolTips: Bool? {
        get { textField?.allowsExpansionToolTips                     }
        set { textField?.allowsExpansionToolTips = newValue ?? false }
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
