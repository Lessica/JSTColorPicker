//
//  TagListSearchField.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/7/5.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

final class TagListSearchField: NSSearchField, UndoProxy {
    lazy var contextUndoManager: UndoManager = { return UndoManager() }()
    override var undoManager: UndoManager? { contextUndoManager }
}

