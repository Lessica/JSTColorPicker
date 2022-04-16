//
//  Screenshot+Error.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/16/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

extension Screenshot {
    override func willPresentError(_ error: Swift.Error) -> Swift.Error {
        debugPrint(error)
        return super.willPresentError(error)
    }
    
    #if APP_STORE
    @discardableResult
    private func presentPlatformSubscriptionRequiredError(_ error: Swift.Error) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = error.localizedDescription
        alert.addButton(withTitle: NSLocalizedString("Subscribe…", comment: "presentError(_:)"))
        let cancelButton = alert.addButton(withTitle: NSLocalizedString("Later", comment: "presentError(_:)"))
        cancelButton.keyEquivalent = "\u{1b}"
        let retVal = alert.runModal() == .alertFirstButtonReturn
        if retVal {
            PurchaseWindowController.shared.showWindow(self)
        }
        return retVal
    }
    #endif
    
    private func presentAdditionalError(_ error: Swift.Error) -> Bool {
        #if APP_STORE
        if let error = error as? Screenshot.Error {
            switch error {
            case .platformSubscriptionRequired:
                presentPlatformSubscriptionRequiredError(error)
                return true
            default:
                break
            }
        } else {
            let error = error as NSError
            if error.code == Screenshot.Error.platformSubscriptionRequired.errorCode {
                presentPlatformSubscriptionRequiredError(error)
                return true
            }
        }
        #endif
        return false
    }
    
    @discardableResult
    override func presentError(_ error: Swift.Error) -> Bool {
        if presentAdditionalError(error) {
            return true
        }
        return super.presentError(error)
    }
}
