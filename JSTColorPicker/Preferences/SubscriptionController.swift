//
//  SubscriptionController.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/20.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa
import MASPreferences

class SubscriptionController: NSViewController {
    
    init() {
        super.init(nibName: "Subscription", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension SubscriptionController: MASPreferencesViewController {
    
    var hasResizableWidth: Bool {
        return false
    }
    
    var hasResizableHeight: Bool {
        return false
    }
    
    var viewIdentifier: String {
        return "SubscriptionPreferences"
    }
    
    var toolbarItemLabel: String? {
        return NSLocalizedString("Subscription", comment: "toolbarItemLabel")
    }
    
    var toolbarItemImage: NSImage? {
        return NSImage(systemSymbolName: "checkmark.seal", accessibilityDescription: "Subscription")
    }
    
}
