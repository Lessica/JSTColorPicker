//
//  TemplateCellView.swift
//  JSTColorPicker
//
//  Created by Darwin on 4/15/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

final class TemplateCellView: NSTableCellView {

    var text: String? {
        get { textField?.stringValue                  }
        set { textField?.stringValue = newValue ?? "" }
    }

    var image: NSImage? {
        get { imageView?.image            }
        set { imageView?.image = newValue }
    }
    
    override var backgroundStyle: NSView.BackgroundStyle {
        get { .normal }
        set { }
    }
}
