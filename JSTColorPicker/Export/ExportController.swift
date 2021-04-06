//
//  ExportController.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/1.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class ExportController: NSViewController, PaneController {
    var menuIdentifier = NSUserInterfaceItemIdentifier("show-export-manager")
    weak var screenshot: Screenshot?

    var isPaneHidden: Bool { view.isHiddenOrHasHiddenAncestor }
    var isPaneStacked: Bool { false }
    @IBOutlet weak var paneBox: NSBox!

    func load(_ screenshot: Screenshot) throws {
        self.screenshot = screenshot
    }

    func reloadPane() {

    }

}
