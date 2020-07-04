//
//  ContentSearchField.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/7/5.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class ContentSearchField: NSTextField, UndoProxy {
    
    public lazy var contextUndoManager: UndoManager = { return UndoManager() }()
    override var undoManager: UndoManager? { contextUndoManager }
    
}

