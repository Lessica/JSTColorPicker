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
        
        NotificationCenter.default.addObserver(self, selector: #selector(loadPreferences(_:)), name: UserDefaults.didChangeNotification, object: nil)
        loadPreferences(nil)
    }
    
    @objc fileprivate func loadPreferences(_ notification: Notification?) {
        gridView.shouldDrawAnnotators = UserDefaults.standard[.drawAnnotatorsInGridView]
    }
    
}
