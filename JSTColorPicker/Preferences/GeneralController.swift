//
//  GeneralController.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/28/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa
import MASPreferences

class GeneralController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        loadPreferences()
    }
    
    init() {
        super.init(nibName: "General", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @IBOutlet weak var drawGridsInSceneButton: NSButton!
    @IBOutlet weak var drawAnnotatorsInGridViewButton: NSButton!
    @IBOutlet weak var hideGridsWhenResizeButton: NSButton!
    @IBOutlet weak var hideAnnotatorsWhenResizeButton: NSButton!
    
    private func loadPreferences() {
        drawGridsInSceneButton.state = UserDefaults.standard[.drawGridsInScene] ? .on : .off
        drawAnnotatorsInGridViewButton.state = UserDefaults.standard[.drawAnnotatorsInGridView] ? .on : .off
        hideGridsWhenResizeButton.state = UserDefaults.standard[.hideGridsWhenResize] ? .on : .off
        hideAnnotatorsWhenResizeButton.state = UserDefaults.standard[.hideAnnotatorsWhenResize] ? .on : .off
    }
    
    @IBAction func drawGridsInSceneButtonAction(_ sender: NSButton) {
        UserDefaults.standard[.drawGridsInScene] = sender.state == .on
        NotificationCenter.default.post(name: .preferencesChanged, object: nil)
        loadPreferences()
    }
    
    @IBAction func drawAnnotatorsInGridViewAction(_ sender: NSButton) {
        UserDefaults.standard[.drawAnnotatorsInGridView] = sender.state == .on
        NotificationCenter.default.post(name: .preferencesChanged, object: nil)
        loadPreferences()
    }
    
    @IBAction func hideGridsWhenResizeAction(_ sender: NSButton) {
        UserDefaults.standard[.hideGridsWhenResize] = sender.state == .on
        NotificationCenter.default.post(name: .preferencesChanged, object: nil)
        loadPreferences()
    }
    
    @IBAction func hideAnnotatorsWhenResizeAction(_ sender: NSButton) {
        UserDefaults.standard[.hideAnnotatorsWhenResize] = sender.state == .on
        NotificationCenter.default.post(name: .preferencesChanged, object: nil)
        loadPreferences()
    }
    
}

extension GeneralController: MASPreferencesViewController {
    
    var viewIdentifier: String {
        return "GeneralPreferences"
    }
    
    var toolbarItemLabel: String? {
        return "General"
    }
    
    var toolbarItemImage: NSImage? {
        return NSImage(named: NSImage.preferencesGeneralName)
    }
    
}
