//
//  TagCellView.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/6/15.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class TagCellView: NSTableCellView {

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            if backgroundStyle == .emphasized {
                textField?.textColor = .white
            } else {
                textField?.textColor = (objectValue as? Tag)?.color
            }
        }
    }
    
}
