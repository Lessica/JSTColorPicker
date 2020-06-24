//
//  TagListTableView.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/5/29.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class TagListTableView: NSTableView {

    override func rightMouseDown(with event: NSEvent) {
        if row(at: convert(event.locationInWindow, from: nil)) < 0 {
            deselectAll(nil)
        }
        super.rightMouseDown(with: event)
    }
    
}
