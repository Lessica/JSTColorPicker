//
//  TemplateInfoController.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/9.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class TemplateInfoController: NSViewController, PaneController {
    var menuIdentifier = NSUserInterfaceItemIdentifier("show-template-information")
    weak var screenshot: Screenshot?

    var isPaneHidden : Bool { view.isHiddenOrHasHiddenAncestor }
    var isPaneStacked: Bool { true }
    @IBOutlet weak var paneBox: NSBox!

    func load(_ screenshot: Screenshot) throws {
        self.screenshot = screenshot
    }

    func reloadPane() {

    }
}
