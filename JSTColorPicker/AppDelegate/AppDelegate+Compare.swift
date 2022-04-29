//
//  AppDelegate+Compare.swift
//  JSTColorPicker
//
//  Created by Darwin on 6/8/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa


extension AppDelegate {
    
    // MARK: - Compare Actions

    struct PixelMatchInput {
        let windowController: WindowController
        let firstImage: PixelImage
        let lastImage: PixelImage
        
        var images: [PixelImage] { [firstImage, lastImage] }
    }
    
    internal var preparedPixelMatchInput: PixelMatchInput? {
        
        guard let managedWindows = tabService?.managedWindows
        else {
            return nil
        }
        
        let preparedManagedWindows = managedWindows
            .filter({ ($0.windowController.screenshot?.state.isLoaded ?? false ) })
        guard preparedManagedWindows.count > 1,
              let firstWindowController = managedWindows.first?.windowController,
              firstWindowController === preparedManagedWindows.first?.windowController,
              let firstImage = firstWindowController.screenshot?.image,
              let lastImage = preparedManagedWindows
                .compactMap({ $0.windowController.screenshot?.image })
                .filter({ $0 !== firstImage })
                .first,
              firstImage.bounds == lastImage.bounds
        else {
            return nil
        }
        
        return PixelMatchInput(
            windowController: firstWindowController,
            firstImage: firstImage,
            lastImage: lastImage
        )
    }
    
    @objc private func compareDocuments(_ sender: Any?) {
        if firstRespondingWindowController?.shouldEndPixelMatchComparison ?? false {
            firstRespondingWindowController?.endPixelMatchComparison()
        }
        else if let matchInput = preparedPixelMatchInput {
            matchInput.windowController.beginPixelMatchComparison(to: matchInput.lastImage)
        }
    }
    
    @IBAction internal func compareDocumentsMenuItemTapped(_ sender: NSMenuItem) {
        compareDocuments(sender)
    }
    
}

