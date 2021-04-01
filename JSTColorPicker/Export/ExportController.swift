//
//  ExportController.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/1.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class ExportController: NSViewController, PaneController {

    internal weak var screenshot: Screenshot?

    var isPaneHidden: Bool { view.isHiddenOrHasHiddenAncestor }

    func load(_ screenshot: Screenshot) throws {

    }

    func reloadPane() {

    }

}
