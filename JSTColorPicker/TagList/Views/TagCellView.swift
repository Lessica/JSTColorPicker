//
//  TagCellView.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/6/15.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class TagCellView: NSTableCellView {
    
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
            guard let tag = objectValue as? Tag else { return }
            if backgroundStyle == .emphasized {
                textField?.textColor = .white
            } else {
                textField?.textColor = tag.color
            }
        }
    }
    
}
