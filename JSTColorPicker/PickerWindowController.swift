//
//  PickerWindowController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/15/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class PickerWindowController: NSWindowController {

    override func windowDidLoad() {
        super.windowDidLoad()
    
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }
    
    var viewController: PickerSplitController {
        get {
            return self.window!.contentViewController as! PickerSplitController
        }
    }

}

extension PickerWindowController {
    
    @IBAction func loadImageAction(sender: NSToolbarItem) {
        viewController.loadImageAction(sender: sender)
    }
    
    @IBAction func useCursorAction(sender: NSToolbarItem) {
        viewController.useCursorAction(sender: sender)
    }
    
    @IBAction func useMagnifyToolAction(sender: NSToolbarItem) {
        viewController.useMagnifyToolAction(sender: sender)
    }
    
    @IBAction func useMinifyToolAction(sender: NSToolbarItem) {
        viewController.useMinifyToolAction(sender: sender)
    }
    
}
