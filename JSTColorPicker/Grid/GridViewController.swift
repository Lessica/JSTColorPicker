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
        
        NotificationCenter.default.addObserver(self, selector: #selector(applyPreferences(_:)), name: UserDefaults.didChangeNotification, object: nil)
        applyPreferences(nil)
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        reloadGridBackground()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func reloadGridBackground() {
        guard let layer = view.layer else { return }
        if drawBackgroundInGridView {
            layer.backgroundColor = NSColor(patternImage: SceneScrollView.checkerboardImage).cgColor
        } else {
            layer.backgroundColor = NSColor.controlBackgroundColor.cgColor
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
