//
//  Links+Ext.swift
//  JSTColorPicker
//
//  Created by Darwin on 4/25/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

extension NSWorkspace {
    
    @discardableResult
    func redirectToManageSubscription() -> Bool {
        if let url = URL(string: "https://buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/manageSubscriptions") {
            return open(url)
        }
        return false
    }
    
    @discardableResult
    func redirectToLocalHelpPage() -> Bool {
        if let url = Bundle.main.url(forResource: "JSTColorPicker", withExtension: "html") {
            return open(url)
        }
        return false
    }
    
    @discardableResult
    func redirectToMainPage() -> Bool {
        if let url = URL(string: "https://82flex.com/jstcpweb/") {
            return open(url)
        }
        return false
    }
    
    @discardableResult
    func redirectToTermsPage() -> Bool {
        if let url = URL(string: "https://82flex.com/jstcpweb/terms.html") {
            return open(url)
        }
        return false
    }
    
    @discardableResult
    func redirectToHelperPage() -> Bool {
        if let url = URL(string: "https://82flex.com/jstcpweb/helper.html") {
            return open(url)
        }
        return false
    }
    
}
