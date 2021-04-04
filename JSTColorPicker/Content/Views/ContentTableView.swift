//
//  ContentTableView.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/21/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol ContentTableViewResponder: class {
    func tableViewAction(_ sender: ContentTableView)
    func tableViewDoubleAction(_ sender: ContentTableView)
}

class ContentTableView: NSTableView, UndoProxy {

    override var isFlipped: Bool { true }
    
    weak var tableViewResponder: ContentTableViewResponder!
    private var hasAttachedSheet: Bool { window?.attachedSheet != nil }
    
    var contextUndoManager: UndoManager?
    override var undoManager: UndoManager? { contextUndoManager }
    
    override func menu(for event: NSEvent) -> NSMenu? {
        guard !hasAttachedSheet else { return nil }
        return super.menu(for: event)
    }
    
    override func keyDown(with event: NSEvent) {
        guard let specialKey = event.specialKey else {
            super.keyDown(with: event)
            return
        }
        let flags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting(.option)
        if flags.isEmpty && (specialKey == .carriageReturn || specialKey == .enter)
        {
            tableViewResponder.tableViewDoubleAction(self)
            return
        }
        super.keyDown(with: event)
    }
    
    override func rightMouseDown(with event: NSEvent) {
        if row(at: convert(event.locationInWindow, from: nil)) < 0 {
            deselectAll(nil)
        }
        super.rightMouseDown(with: event)
    }

    override var gridColor: NSColor {
        get { NSColor.separatorColor }
        set { }
    }
    
}
