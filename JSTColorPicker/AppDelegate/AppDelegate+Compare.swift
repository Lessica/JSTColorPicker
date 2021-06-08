//
//  AppDelegate+Compare.swift
//  JSTColorPicker
//
//  Created by Rachel on 6/8/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa


extension AppDelegate {
    
    // MARK: - Compare Actions
    
    internal var preparedPixelMatchTuple: (WindowController, [PixelImage])? {
        guard let managedWindows = tabService?.managedWindows else { return nil }
        let preparedManagedWindows = managedWindows.filter({ ($0.windowController.screenshot?.state.isLoaded ?? false ) })
        guard preparedManagedWindows.count >= 2,
              let firstWindowController = managedWindows.first?.windowController,
              let firstPreparedWindowController = preparedManagedWindows.first?.windowController,
              firstWindowController === firstPreparedWindowController
        else { return nil }
        return (firstWindowController, preparedManagedWindows.compactMap({ $0.windowController.screenshot?.image }))
    }
    
    @objc private func compareDocuments(_ sender: Any?) {
        if firstManagedWindowController?.shouldEndPixelMatchComparison ?? false {
            firstManagedWindowController?.endPixelMatchComparison()
        }
        else if let tuple = preparedPixelMatchTuple {
            if let frontPixelImage = tuple.0.screenshot?.image {
                if let anotherPixelImage = tuple.1.first(where: { $0 !== frontPixelImage }) {
                    tuple.0.beginPixelMatchComparison(to: anotherPixelImage)
                }
            }
        }
    }
    
    @IBAction internal func compareDocumentsMenuItemTapped(_ sender: NSMenuItem) {
        compareDocuments(sender)
    }
    
}

