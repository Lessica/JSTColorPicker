//
//  GridViewController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/20/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class GridViewController: NSViewController {
    
    @IBOutlet weak var gridView        : GridView!
    private        let observableKeys  : [UserDefaults.Key] = [.drawBackgroundInGridView, .drawAnnotatorsInGridView, .gridViewSizeLevel, .gridViewAnimationSpeed]
    private        var observables     : [Observable]?
    
    var drawBackgroundInGridView: Bool = UserDefaults.standard[.drawBackgroundInGridView] {
        didSet {
            reloadGridBackground()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        prepareDefaults()
        observables = UserDefaults.standard.observe(keys: observableKeys, callback: { [weak self] in self?.applyDefaults($0, $1, $2) })
    }

    private func prepareDefaults() {
        drawBackgroundInGridView = UserDefaults.standard[.drawBackgroundInGridView]
        gridView.shouldDrawAnnotators = UserDefaults.standard[.drawAnnotatorsInGridView]
        gridView.setNeedsDisplayAll()
    }

    private func applyDefaults(_ defaults: UserDefaults, _ defaultKey: UserDefaults.Key, _ defaultValue: Any) {
        if defaultKey == .drawBackgroundInGridView, let toValue = defaultValue as? Bool {
            if self.drawBackgroundInGridView != toValue {
                self.drawBackgroundInGridView = toValue
            }
        }
        else if defaultKey == .drawAnnotatorsInGridView, let toValue = defaultValue as? Bool {
            if self.gridView.shouldDrawAnnotators != toValue {
                self.gridView.shouldDrawAnnotators = toValue
                self.gridView.setNeedsDisplayAll()
            }
        }
        else if defaultKey == .gridViewSizeLevel || defaultKey == .gridViewAnimationSpeed {
            self.gridView.applyFromDefaults()
        }
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        reloadGridBackground()
    }
    
    private func reloadGridBackground() {
        guard let layer = view.layer else { return }
        if drawBackgroundInGridView {
            layer.backgroundColor = NSColor(patternImage: SceneScrollView.checkerboardImage).cgColor
        } else {
            layer.backgroundColor = NSColor.controlBackgroundColor.cgColor
        }
    }
    
}
