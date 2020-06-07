//
//  EditAreaController.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/6/5.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class EditAreaController: EditViewController {
    
    @IBOutlet weak var box      : NSBox!

    @IBOutlet weak var cancelBtn    : NSButton!
    @IBOutlet weak var okBtn        : NSButton!
    
    @IBOutlet weak var textFieldOriginX  : NSTextField!
    @IBOutlet weak var textFieldOriginY  : NSTextField!
    @IBOutlet weak var textFieldWidth    : NSTextField!
    @IBOutlet weak var textFieldHeight   : NSTextField!
    @IBOutlet weak var textFieldOppositeX: NSTextField!
    @IBOutlet weak var textFieldOppositeY: NSTextField!
    
    @IBOutlet weak var textFieldError    : NSTextField!
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        updateDisplay(with: contentItem)
        if isAdd {
            box.title = NSLocalizedString("New Area", comment: "EditAreaController")
        } else {
            box.title = NSLocalizedString("Edit Area", comment: "EditAreaController")
            validateInputs(nil)
        }
    }
    
    private func updateDisplay(with item: ContentItem?) {
        guard let pixelArea = item as? PixelArea else { return }
        
        textFieldOriginX  .stringValue = String(pixelArea.rect.minX)
        textFieldOriginY  .stringValue = String(pixelArea.rect.minY)
        textFieldWidth    .stringValue = String(pixelArea.rect.width)
        textFieldHeight   .stringValue = String(pixelArea.rect.height)
        textFieldOppositeX.stringValue = String(pixelArea.rect.maxX)
        textFieldOppositeY.stringValue = String(pixelArea.rect.maxY)
    }
    
    private func testContentItem(fromOpposite: Bool, with item: ContentItem? = nil) throws -> ContentItem? {
        guard let dataSource = contentDataSource else { return nil }
        let replRect = (fromOpposite ?
            PixelRect(
                coordinate1: PixelCoordinate(
                    x: textFieldOriginX.integerValue,
                    y: textFieldOriginY.integerValue
                ),
                coordinate2: PixelCoordinate(
                    x: textFieldOppositeX.integerValue,
                    y: textFieldOppositeY.integerValue
                )
            ) :
            PixelRect(
                origin: PixelCoordinate(
                    x: textFieldOriginX.integerValue,
                    y: textFieldOriginY.integerValue
                ),
                size: PixelSize(
                    width: textFieldWidth.integerValue,
                    height: textFieldHeight.integerValue
                )
            )
        )
        let replItem = try dataSource.contentItem(of: replRect)
        if let origItem = item {
            replItem.copyFrom(origItem)
        }
        return replItem
    }
    
    @IBAction private func validateInputs(_ sender: NSTextField?) {
        do {
            let item = try testContentItem(fromOpposite: sender == textFieldOppositeX || sender == textFieldOppositeY)
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
        guard let window = view.window, let parent = window.sheetParent else { return }
        do {
            let origItem: ContentItem? = contentItem
            if let replItem = try testContentItem(fromOpposite: false, with: origItem) as? PixelArea
            {
                if isAdd {
                    if let _ = try delegate.addContentItem(of: replItem.rect) {
                        parent.endSheet(window, returnCode: .OK)
                    }
                } else {
                    guard let origItem = origItem else { return }
                    if let _ = try delegate.updateContentItem(origItem, to: replItem.rect) {
                        parent.endSheet(window, returnCode: .OK)
                    }
                }
            }
        } catch {
            presentError(error)
        }
    }
    
}
