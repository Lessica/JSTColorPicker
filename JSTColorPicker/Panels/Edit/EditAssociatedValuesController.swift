//
//  EditAssociatedValuesController.swift
//  JSTColorPicker
//
//  Created by Darwin on 6/29/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

@objc
class AssociatedKeyPath: NSObject, NSCopying {
    internal init(name: String, type: AssociatedKeyPath.ValueType, value: Any? = nil, options: [String]? = nil) {
        self.name = name
        self.type = type
        self.value = value
        self.options = options
        super.init()
    }

    static var initializedOrder = 0

    override init() {
        AssociatedKeyPath.initializedOrder += 1
        name = "keyPath #\(AssociatedKeyPath.initializedOrder)"
        type = .Boolean
        value = false
        options = nil
        super.init()
    }

    @objc
    enum ValueType: Int {
        case Boolean // checkbox
        case Integer // text input
        case Decimal // text input
        case String // text input
        case Point // not implemented
        case Size // not implemented
        case Rect // not implemented
        case Range // not implemented
        case Color // not implemented
        case Image // not implemented
        case Nil // nothing
    }

    @objc dynamic var name: String
    @objc dynamic var type: ValueType {
        didSet {
            switch type {
            case .Boolean:
                isCheckboxValue = true
                isTextInputValue = false
                isTextInputIntegerValue = false
                isTextInputDecimalValue = false
            case .Integer:
                isCheckboxValue = false
                isTextInputValue = false
                isTextInputIntegerValue = true
                isTextInputDecimalValue = false
            case .Decimal:
                isCheckboxValue = false
                isTextInputValue = false
                isTextInputIntegerValue = false
                isTextInputDecimalValue = true
            case .String:
                isCheckboxValue = false
                isTextInputValue = true
                isTextInputIntegerValue = false
                isTextInputDecimalValue = false
            case .Point:
                isCheckboxValue = false
                isTextInputValue = false
                isTextInputIntegerValue = false
                isTextInputDecimalValue = false
            case .Size:
                isCheckboxValue = false
                isTextInputValue = false
                isTextInputIntegerValue = false
                isTextInputDecimalValue = false
            case .Rect:
                isCheckboxValue = false
                isTextInputValue = false
                isTextInputIntegerValue = false
                isTextInputDecimalValue = false
            case .Range:
                isCheckboxValue = false
                isTextInputValue = false
                isTextInputIntegerValue = false
                isTextInputDecimalValue = false
            case .Color:
                isCheckboxValue = false
                isTextInputValue = false
                isTextInputIntegerValue = false
                isTextInputDecimalValue = false
            case .Image:
                isCheckboxValue = false
                isTextInputValue = false
                isTextInputIntegerValue = false
                isTextInputDecimalValue = false
            case .Nil:
                isCheckboxValue = false
                isTextInputValue = false
                isTextInputIntegerValue = false
                isTextInputDecimalValue = false
            }
        }
    }

    @objc dynamic var value: Any?
    @objc dynamic var options: [String]? {
        didSet {
            hasOptions = options != nil
        }
    }

    @objc dynamic var hasOptions = false
    @objc dynamic var isCheckboxValue = true
    @objc dynamic var isTextInputValue = false
    @objc dynamic var isTextInputIntegerValue = false
    @objc dynamic var isTextInputDecimalValue = false

    func copy(with zone: NSZone? = nil) -> Any {
        return AssociatedKeyPath(
            name: name,
            type: type,
            value: value,
            options: options
        )
    }
}

final class EditAssociatedValuesController: EditViewController, NSTableViewDataSource, NSTableViewDelegate, NSMenuItemValidation, EditArrayControllerDelegate
{
    @IBOutlet var box: NSBox!
    @IBOutlet var tableView: NSTableView!
    @IBOutlet var arrayController: NSArrayController!

    @IBOutlet var cancelBtn: NSButton!
    @IBOutlet var okBtn: NSButton!

    @IBOutlet var touchBarCancelBtn: NSButton!
    @IBOutlet var touchBarOkBtn: NSButton!

    @IBOutlet var columnKeyPathName: NSTableColumn!
    @IBOutlet var columnKeyPathType: NSTableColumn!
    @IBOutlet var columnKeyPathValue: NSTableColumn!

    override func viewDidLoad() {
        super.viewDidLoad()

        okBtn.isEnabled = false
        touchBarOkBtn.isEnabled = false
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        undoManager?.disableUndoRegistration()
        populateTable()
        undoManager?.enableUndoRegistration()
        
        if let undoManager = undoManager, undoToken == nil && redoToken == nil {
            undoToken = NotificationCenter.default.observe(
                name: NSNotification.Name.NSUndoManagerDidUndoChange,
                object: undoManager
            )
            { [unowned self] (notification) in
                print(notification)
            }
            redoToken = NotificationCenter.default.observe(
                name: NSNotification.Name.NSUndoManagerDidRedoChange,
                object: undoManager
            )
            { [unowned self] (notification) in
                print(notification)
            }
        }
    }

    private func populateTable() {
        if let tagManager = tagManager,
           let tagString = contentItem?.firstTag,
           let tag = tagManager.managedTag(of: tagString),
           let tagFields = tag.fields.array as? [Field] {
            for tagField in tagFields {
                print(tagField)
            }
        }
    }
    
    func contentsArrayWillUpdate(_ sender: EditArrayController) {
        
    }
    
    func contentsArrayDidUpdate(_ sender: EditArrayController) {
        undoManager?.registerUndo(withTarget: self, handler: <#T##(TargetType) -> Void#>)
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(delete(_:)) {
            return arrayController.isEditable && arrayController.selectionIndexes.count > 0
        }
        return false
    }
    
    @IBAction func delete(_ sender: Any) {
        arrayController.remove(sender)
    }

    @IBAction private func cancelAction(_ sender: NSButton) {
        guard let window = view.window, let parent = window.sheetParent else { return }
        parent.endSheet(window, returnCode: .cancel)
    }

    @IBAction private func okAction(_ sender: NSButton) {
        
    }
}
