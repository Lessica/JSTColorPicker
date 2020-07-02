//
//  TagListTableView.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/5/29.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class TagListTableView: NSTableView {
    
    public var isEmbeddedMode: Bool = false
    
    private var hasAttachedSheet: Bool {
        return window?.attachedSheet != nil
    }
    
    override func menu(for event: NSEvent) -> NSMenu? {
        if hasAttachedSheet
            || isEmbeddedMode
        { return nil }
        return super.menu(for: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        if row(at: convert(event.locationInWindow, from: nil)) < 0 {
            deselectAll(nil)
        }
        super.rightMouseDown(with: event)
    }
    
}
