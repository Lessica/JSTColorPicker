//
//  PaddleLicenseActivationViewController.swift
//  JSTColorPickerSparkle
//
//  Created by Rachel on 4/20/22.
//  Copyright © 2022 JST. All rights reserved.
//

import Cocoa

final class PaddleLicenseActivationViewController: NSViewController, NSTextFieldDelegate {
    
    static let windowStoryboardIdentifier = NSStoryboard.SceneIdentifier("PaddleLicenseActivationWindowController")
    
    @IBOutlet private weak var emailAddressInput: NSTextField!
    @IBOutlet private weak var licenseCodeInput: NSTextField!
    @IBOutlet private weak var forgotButton: NSButton!
    @IBOutlet private weak var cancelButton: NSButton!
    @IBOutlet private weak var okButton: NSButton!
    
    var emailAddress: String {
        return emailAddressInput.stringValue
    }
    
    var licenseCode: String {
        return licenseCodeInput.stringValue
    }
    
    @IBAction private func cancelButtonTapped(_ sender: NSButton) {
        guard let window = view.window, let parent = window.sheetParent else { return }
        parent.endSheet(window, returnCode: .cancel)
    }
    
    @IBAction private func okButtonTapped(_ sender: NSButton) {
        guard let window = view.window, let parent = window.sheetParent else { return }
        parent.endSheet(window, returnCode: .OK)
    }
    
    @IBAction private func forgotButtonTapped(_ sender: NSButton) {
        guard let window = view.window, let parent = window.sheetParent else { return }
        parent.endSheet(window, returnCode: .continue)
    }
    
    func controlTextDidChange(_ obj: Notification) {
        okButton.isEnabled = !emailAddressInput.stringValue.isEmpty && !licenseCodeInput.stringValue.isEmpty
    }
    
}
