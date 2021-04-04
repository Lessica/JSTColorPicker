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
    
    var drawBackgroundInGridView: Bool = UserDefaults.standard[.drawBackgroundInGridView] {
        didSet {
            reloadGridBackground()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        reloadGridBackground()
        
        NotificationCenter.default.addObserver(self, selector: #selector(applyPreferences(_:)), name: UserDefaults.didChangeNotification, object: nil)
        applyPreferences(nil)
    }
    
    private func reloadGridBackground() {
        if drawBackgroundInGridView {
            view.layer?.backgroundColor = NSColor(patternImage: NSImage(named: "JSTBackgroundPattern")!).cgColor
        }
        else {
            view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        }
    }
    
    @objc private func applyPreferences(_ notification: Notification?) {
        let drawBackgroundInGridView: Bool = UserDefaults.standard[.drawBackgroundInGridView]
        if self.drawBackgroundInGridView != drawBackgroundInGridView {
            self.drawBackgroundInGridView = drawBackgroundInGridView
        }
        let drawAnnotatorsInGridView: Bool = UserDefaults.standard[.drawAnnotatorsInGridView]
        if gridView.shouldDrawAnnotators != drawAnnotatorsInGridView {
            gridView.shouldDrawAnnotators = drawAnnotatorsInGridView
            gridView.setNeedsDisplayAll()
        }
    }
    
}
