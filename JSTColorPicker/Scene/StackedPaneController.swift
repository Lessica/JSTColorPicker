//
//  StackedPaneController.swift
//  JSTColorPicker
//
//  Created by Rachel on 4/15/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class StackedPaneController: NSViewController, PaneController {
    var menuIdentifier: NSUserInterfaceItemIdentifier { NSUserInterfaceItemIdentifier("") }
    
    @objc dynamic weak var screenshot  : Screenshot?
    @IBOutlet weak var paneBox         : NSBox!

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadPane()
    }

    private var isViewHidden: Bool = true

    override func viewWillAppear() {
        super.viewWillAppear()
        isViewHidden = false
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        isViewHidden = true
    }

    var isPaneHidden : Bool { view.isHiddenOrHasHiddenAncestor || isViewHidden }
    var isPaneStacked: Bool { false }

    func load(_ screenshot: Screenshot) throws {
        self.screenshot = screenshot
    }

    func reloadPane() { }
}
