//
//  EditAssociatedValuesTableView.swift
//  JSTColorPicker
//
//  Created by Mason Rachel on 2022/3/23.
//  Copyright © 2022 JST. All rights reserved.
//

import Cocoa

final class EditAssociatedValuesTableView: NSTableView {
    var contextUndoManager: UndoManager?
    override var undoManager: UndoManager? { contextUndoManager ?? super.undoManager }
}
