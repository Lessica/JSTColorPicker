//
//  EditWindowController.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/6/7.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class EditWindowController: NSWindowController {
    
    private lazy var internalUndoManager: UndoManager = { return UndoManager() }()

    override func windowDidLoad() {
        super.windowDidLoad()
    
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }

}

extension EditWindowController: NSWindowDelegate {
    
    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        if window == self.window {
            return internalUndoManager
        }
        return nil
    }
    
}
