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
    
    @IBOutlet weak var tabView: NSTabView!
    @objc dynamic var maximumCount: Int = 9999
    @objc dynamic var minimumCount: Int = 1
    
    init() {
        super.init(nibName: "General", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        tabView.selectFirstTabViewItem(nil)
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        tabView.selectFirstTabViewItem(nil)
    }
    
}

extension GeneralController: MASPreferencesViewController {
    
    var hasResizableWidth: Bool {
        return false
    }
    
    var hasResizableHeight: Bool {
        return false
    }
    
    var viewIdentifier: String {
        return "GeneralPreferences"
    }
    
    var toolbarItemLabel: String? {
        return NSLocalizedString("General", comment: "toolbarItemLabel")
    }
    
    var toolbarItemImage: NSImage? {
        return NSImage(named: NSImage.preferencesGeneralName)
    }
    
}
