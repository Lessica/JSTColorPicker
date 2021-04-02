//
//  PaneController.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/1.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

protocol PaneController: NSViewController, ScreenshotLoader {
    var paneBox: NSBox! { get }
    var isPaneHidden: Bool { get }
    
    func reloadPane()
}
