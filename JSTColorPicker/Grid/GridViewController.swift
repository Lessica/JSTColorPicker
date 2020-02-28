//
//  GridViewController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/20/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class GridViewController: NSViewController {
    
    @IBOutlet weak var gridView: GridView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(patternImage: NSImage(named: "JSTBackgroundPattern")!).cgColor
        
        NotificationCenter.default.addObserver(self, selector: #selector(loadPreferences), name: .preferencesChanged, object: nil)
        loadPreferences()
    }
    
    @objc fileprivate func loadPreferences() {
        gridView.shouldDrawAnnotators = UserDefaults.standard[.drawAnnotatorsInGridView]
    }
    
}
