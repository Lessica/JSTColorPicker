//
//  PaddleLicenseActivationViewController.swift
//  JSTColorPickerSparkle
//
//  Created by Darwin on 4/20/22.
//  Copyright © 2022 JST. All rights reserved.
//

import Cocoa

extension NSApplication.ModalResponse {
    static let invalidEmailAddress = NSApplication.ModalResponse(rawValue: 7001)
    static let invalidLicenseCode = NSApplication.ModalResponse(rawValue: 7002)
}

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
    
    private func isValidEmail(_ email: String) -> Bool {
        guard email.count <= 254 else {
            return false
        }
        let pos = email.lastIndex(of: "@") ?? email.endIndex
        return (pos != email.startIndex)
            && ((email.lastIndex(of: ".") ?? email.startIndex) > pos)
            && (email[pos...].count > 4)
    }
    
    @IBAction private func okButtonTapped(_ sender: NSButton) {
        let maxSlices = 5
        let sliceLength = 8
        let splitSymbol = "-"
        let allowedCharacters = CharacterSet.decimalDigits
            .union(CharacterSet(charactersIn: "abcdefABCDEF"))
        let licenseComponents = licenseCode
            .filter({ allowedCharacters.contains($0.unicodeScalars.first!) })
            .uppercased().split(by: sliceLength)
        licenseCodeInput.stringValue = licenseComponents
            .dropLast(max(0, licenseComponents.count - maxSlices))
            .joined(separator: splitSymbol)
        
        guard let window = view.window,
              let parent = window.sheetParent else { return }
        
        guard isValidEmail(emailAddress)
        else {
            parent.endSheet(window, returnCode: .invalidEmailAddress)
            return
        }
        
        guard licenseCode.count == 44
        else {
            parent.endSheet(window, returnCode: .invalidLicenseCode)
            return
        }
        
        parent.endSheet(window, returnCode: .OK)
    }
    
    @IBAction private func forgotButtonTapped(_ sender: NSButton) {
        guard let window = view.window,
              let parent = window.sheetParent else { return }
        parent.endSheet(window, returnCode: .continue)
    }
    
    func controlTextDidChange(_ obj: Notification) {
        okButton.isEnabled = !emailAddress.isEmpty && !licenseCode.isEmpty  // && licenseCode.count == 44
    }
    
}
