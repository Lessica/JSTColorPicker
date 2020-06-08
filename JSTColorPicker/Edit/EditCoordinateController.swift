//
//  EditCoordinateController.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/6/5.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class EditCoordinateController: EditViewController {
    
    @IBOutlet weak var box      : NSBox!
    
    @IBOutlet weak var cancelBtn: NSButton!
    @IBOutlet weak var okBtn    : NSButton!
    
    @IBOutlet weak var textFieldOriginX: NSTextField!
    @IBOutlet weak var textFieldOriginY: NSTextField!
    @IBOutlet weak var textFieldColor  : NSTextField!
    
    @IBOutlet weak var textFieldError  : NSTextField!
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        undoManager?.beginUndoGrouping()
        updateDisplay(nil, with: contentItem)
        if isAdd {
            box.title = NSLocalizedString("New Color & Coordinate", comment: "EditCoordinateController")
        } else {
            box.title = NSLocalizedString("Edit Color & Coordinate", comment: "EditCoordinateController")
            validateInputs(view)
        }
        undoManager?.endUndoGrouping()
        
        undoToken = NotificationCenter.default.observe(name: NSNotification.Name.NSUndoManagerDidUndoChange, object: nil)
        { [unowned self] (notification) in
            guard (notification.object as? UndoManager) == self.undoManager else { return }
            self.validateInputs(nil)
        }
        redoToken = NotificationCenter.default.observe(name: NSNotification.Name.NSUndoManagerDidRedoChange, object: nil)
        { [unowned self] (notification) in
            guard (notification.object as? UndoManager) == self.undoManager else { return }
            self.validateInputs(nil)
        }
    }
    
    private var lastDisplayedColor: PixelColor?
    
    private func updateDisplay(_ sender: Any?, with item: ContentItem?) {
        guard let pixelColor = item as? PixelColor else { return }
        
        textFieldOriginX.stringValue   = String(pixelColor.coordinate.x)
        textFieldOriginY.stringValue   = String(pixelColor.coordinate.y)
        textFieldColor  .stringValue   = "\u{25CF} \(pixelColor.cssString)"
        
        let nsColor = pixelColor.toNSColor()
        textFieldColor.textColor       = nsColor
        textFieldColor.backgroundColor = (nsColor.isLightColor ?? false) ? .black : .white
        
        if let lastDisplayedColor = lastDisplayedColor, lastDisplayedColor.coordinate != pixelColor.coordinate, sender != nil
        {
            undoManager?.beginUndoGrouping()
            undoManager?.registerUndo(withTarget: self, handler: { (targetSelf) in
                if let field = sender as? NSTextField, targetSelf.firstResponder != field
                {
                    targetSelf.makeFirstResponder(field)
                } else {
                    targetSelf.makeFirstResponder(nil)
                }
                targetSelf.updateDisplay(sender, with: lastDisplayedColor)
            })
            undoManager?.endUndoGrouping()
        }
        
        if sender != nil {
            lastDisplayedColor = pixelColor
        }
    }
    
    private func testContentItem(with item: ContentItem? = nil) throws -> ContentItem? {
        guard let dataSource = contentDataSource else { return nil }
        let replItem = try dataSource.contentItem(of: PixelCoordinate(x: textFieldOriginX.integerValue, y: textFieldOriginY.integerValue))
        if let origItem = item {
            replItem.copyFrom(origItem)
        }
        return replItem
    }
    
    @IBAction private func validateInputs(_ sender: Any?) {
        do {
            let item = try testContentItem()
            updateDisplay(sender, with: item)
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
            if let replItem = try testContentItem(with: origItem) as? PixelColor
            {
                if isAdd {
                    if let _ = try delegate.addContentItem(of: replItem.coordinate) {
                        parent.endSheet(window, returnCode: .OK)
                    }
                } else {
                    guard let origItem = origItem else { return }
                    if let _ = try delegate.updateContentItem(origItem, to: replItem.coordinate) {
                        parent.endSheet(window, returnCode: .OK)
                    }
                }
            }
        } catch {
            presentError(error)
        }
    }
    
    deinit {
        debugPrint("- [EditCoordinateController deinit]")
    }
    
}
