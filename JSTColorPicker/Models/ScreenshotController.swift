//
//  ScreenshotController.swift
//  JSTColorPicker
//
//  Created by Darwin on 2022/4/23.
//  Copyright © 2022 JST. All rights reserved.
//

import Foundation

@objc
final class ScreenshotController: NSDocumentController {
    
    @objc
    public func openScreenshot(
        withContentsOfURL url: URL,
        display displayDocument: Bool
    ) {
        self.openDocument(withContentsOf: url, display: displayDocument) {
            (document, documentWasAlreadyOpen, error) in
            NotificationCenter.default.post(name: .dropRespondingWindowChanged, object: nil)
            if let error = error {
                self.presentError(error)
            }
        }
    }
}
