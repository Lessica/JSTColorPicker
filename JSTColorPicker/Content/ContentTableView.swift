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

class ContentTableView: NSTableView {
    
    weak var tableViewResponder: ContentTableViewResponder?
    
    override func keyDown(with event: NSEvent) {
        guard let specialKey = event.specialKey else {
            super.keyDown(with: event)
            return
        }
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty && (specialKey == .carriageReturn || specialKey == .enter) {
            tableViewResponder?.tableViewDoubleAction(self)
            return
        }
        super.keyDown(with: event)
    }
    
}
