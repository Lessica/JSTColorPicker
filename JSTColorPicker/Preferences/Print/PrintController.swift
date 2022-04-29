//
//  PrintController.swift
//  JSTColorPicker
//
//  Created by Darwin on 2022/4/7.
//  Copyright © 2022 JST. All rights reserved.
//

import Cocoa
import MASPreferences

final class PrintController: NSViewController {
    
    static let Identifier = "PrintPreferences"
    private let inPageSetup: Bool
    
    @IBOutlet var largerWidthConstraint: NSLayoutConstraint!
    @IBOutlet var smallerWidthConstraint: NSLayoutConstraint!
    
    init(inPageSetup: Bool = false) {
        self.inPageSetup = inPageSetup
        super.init(nibName: "Print", bundle: nil)
        self.view.translatesAutoresizingMaskIntoConstraints = !inPageSetup
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        if inPageSetup {
            largerWidthConstraint.isActive = false
        }
    }
}

extension PrintController: MASPreferencesViewController {
    
    var hasResizableWidth: Bool {
        return false
    }
    
    var hasResizableHeight: Bool {
        return false
    }
    
    var viewIdentifier: String {
        return PrintController.Identifier
    }
    
    var toolbarItemLabel: String? {
        return NSLocalizedString("Print", comment: "toolbarItemLabel")
    }
    
    var toolbarItemImage: NSImage? {
        return NSImage(systemSymbolName: "printer", accessibilityDescription: "Print")
    }
    
}
