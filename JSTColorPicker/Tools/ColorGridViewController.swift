//
//  ColorGridViewController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/20/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class ColorGridViewController: NSViewController {
    
    @IBOutlet weak var gridView: ColorGridView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(patternImage: NSImage(named: "JSTBackgroundPattern")!).cgColor
    }
    
}
