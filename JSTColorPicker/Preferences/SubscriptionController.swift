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
    
    @IBOutlet weak var detailLabel: NSTextField!
    
    init() {
        super.init(nibName: "Subscription", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        detailLabel.stringValue = String(
            format: NSLocalizedString("Valid Subscription: %@", comment: "PurchaseManager"),
            PurchaseManager.shared.productType == .subscribed
                ? PurchaseManager.shared.readableExpiredAt
                : NSLocalizedString("None", comment: "PurchaseManager")
        )
    }
    
    @IBAction func viewSubscriptionAction(_ sender: NSButton) {
        PurchaseWindowController.shared.showWindow(sender)
    }
    
    @IBAction func manageSubscriptionAction(_ sender: NSButton) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = NSLocalizedString("Open Confirmation", comment: "manageSubscriptionAction(_:)")
        alert.informativeText = NSLocalizedString("Will redirect to your Apple ID account page to manage your subscription, continue?", comment: "manageSubscriptionAction(_:)")
        alert.addButton(withTitle: NSLocalizedString("OK", comment: "manageSubscriptionAction(_:)"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "manageSubscriptionAction(_:)"))
        alert.beginSheetModal(for: view.window!) { resp in
            if resp == .alertFirstButtonReturn {
                if let url = URL(string: "https://buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/manageSubscriptions") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
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
