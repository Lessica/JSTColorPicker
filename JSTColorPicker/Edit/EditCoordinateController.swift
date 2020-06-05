//
//  EditCoordinateController.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/6/5.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class EditCoordinateController: EditViewController {
    
    @IBOutlet weak var cancelBtn: NSButton!
    @IBOutlet weak var okBtn    : NSButton!
    
    @IBOutlet weak var textFieldOriginX: NSTextField!
    @IBOutlet weak var textFieldOriginY: NSTextField!
    @IBOutlet weak var textFieldColor  : NSTextField!
    
    @IBOutlet weak var textFieldError  : NSTextField!
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        updateDisplay(with: contentItem)
        validateInputs(nil)
    }
    
    private func updateDisplay(with item: ContentItem?) {
        guard let pixelColor = item as? PixelColor else { return }
        
        textFieldOriginX.stringValue   = String(pixelColor.coordinate.x)
        textFieldOriginY.stringValue   = String(pixelColor.coordinate.y)
        textFieldColor  .stringValue   = "\u{25CF} \(pixelColor.cssString)"
        
        let nsColor = pixelColor.toNSColor()
        textFieldColor.textColor       = nsColor
        textFieldColor.backgroundColor = (nsColor.isLightColor ?? false) ? .black : .white
    }
    
    private func testContentItem(with item: ContentItem? = nil) throws -> ContentItem? {
        guard let dataSource = contentDataSource else { return nil }
        let replItem = try dataSource.contentItem(of: PixelCoordinate(x: textFieldOriginX.integerValue, y: textFieldOriginY.integerValue))
        if let origItem = item {
            replItem.copyFrom(origItem)
        }
        return replItem
    }
    
    @IBAction private func validateInputs(_ sender: NSTextField?) {
        do {
            let item = try testContentItem()
            updateDisplay(with: item)
            okBtn.isEnabled = (item != contentItem)
            textFieldError.isHidden = true
        } catch {
            textFieldError.stringValue = "\n\(error.localizedDescription)"
            okBtn.isEnabled = false
            textFieldError.isHidden = false
        }
    }
    
    @IBAction private func cancelAction(_ sender: NSButton) {
        guard let window = view.window, let parent = window.sheetParent else { return }
        parent.endSheet(window, returnCode: .cancel)
    }
    
    @IBAction private func okAction(_ sender: NSButton) {
        guard let delegate = contentDelegate else { return }
        guard let origItem = contentItem else { return }
        guard let window = view.window, let parent = window.sheetParent else { return }
        do {
            if let replItem = try testContentItem(with: origItem) as? PixelColor
            {
                if let _ = try delegate.updateContentItem(origItem, to: replItem.coordinate) {
                    parent.endSheet(window, returnCode: .OK)
                }
            }
        } catch {
            presentError(error)
        }
    }
    
}
