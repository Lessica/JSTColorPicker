//
//  SubscriptionController.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/20.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa
import MASPreferences

final class SubscriptionController: NSViewController {
    
    @IBOutlet weak var detailLabel: NSTextField!
    
    init() {
        super.init(nibName: "Subscription", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        reloadDetailUI()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(productTypeDidChange(_:)),
            name: PurchaseManager.productTypeDidChangeNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @IBAction private func viewSubscriptionAction(_ sender: NSButton) {
        PurchaseWindowController.shared.showWindow(sender)
    }
    
    @IBAction private func manageSubscriptionAction(_ sender: NSButton) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString("Open Confirmation", comment: "manageSubscriptionAction(_:)")
        alert.informativeText = NSLocalizedString("Will redirect to your Apple ID account page to manage your subscription, continue?", comment: "manageSubscriptionAction(_:)")
        alert.addButton(withTitle: NSLocalizedString("OK", comment: "manageSubscriptionAction(_:)"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "manageSubscriptionAction(_:)"))
        alert.beginSheetModal(for: view.window!) { resp in
            if resp == .alertFirstButtonReturn {
                NSWorkspace.shared.redirectToManageSubscription()
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
    
    @objc private func productTypeDidChange(_ noti: Notification) {
        guard let manager = noti.object as? PurchaseManager else { return }
        DispatchQueue.main.async {
            self.reloadDetailUI(from: manager)
        }
    }
    
    private func reloadDetailUI(from manager: PurchaseManager? = nil) {
        let currentManager = manager ?? PurchaseManager.shared
        detailLabel.stringValue = String(
            format: NSLocalizedString("Valid Subscription: %@", comment: "PurchaseManager"),
            currentManager.getProductType() == .subscribed
                ? currentManager.getMediumReadableExpiredAt()
                : NSLocalizedString("None", comment: "PurchaseManager")
        )
    }
    
}
