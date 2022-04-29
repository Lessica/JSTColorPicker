//
//  ContentSearchField.swift
//  JSTColorPicker
//
//  Created by Darwin on 2020/7/5.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

final class ContentSearchField: NSTextField, UndoProxy {
    lazy var contextUndoManager: UndoManager = { return UndoManager() }()
    override var undoManager: UndoManager? { contextUndoManager }
}

