//
//  SidebarSplitView.swift
//  JSTColorPicker
//
//  Created by Darwin on 5/3/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class SidebarSplitView: NSSplitView {
    
    private var hasAttachedSheet: Bool { window?.attachedSheet != nil }
    override func menu(for event: NSEvent) -> NSMenu? {
        guard !hasAttachedSheet else { return nil }
        return super.menu(for: event)
    }
    
}
