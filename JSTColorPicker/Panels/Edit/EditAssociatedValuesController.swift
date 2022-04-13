//
//  EditAssociatedValuesController.swift
//  JSTColorPicker
//
//  Created by Darwin on 6/29/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa
import OrderedCollections

final class EditAssociatedValuesController: EditViewController, NSTableViewDataSource, NSTableViewDelegate, NSMenuItemValidation, EditArrayControllerDelegate, NSMenuDelegate
{
    
    @IBOutlet var box: NSBox!
    @IBOutlet var tableView: EditAssociatedValuesTableView!
    @IBOutlet var arrayController: EditArrayController!
    private var arrangedAssociatedKeyPaths: [AssociatedKeyPath]
    { arrayController.arrangedObjects as? [AssociatedKeyPath] ?? [] }
    private var isEditable: Bool { loader?.screenshot?.state.isWritable ?? arrayController.isEditable }

    @IBOutlet var cancelBtn: NSButton!
    @IBOutlet var okBtn: NSButton!

    @IBOutlet var touchBarCancelBtn: NSButton!
    @IBOutlet var touchBarOkBtn: NSButton!

    @IBOutlet var columnKeyPathName: NSTableColumn!
    @IBOutlet var columnKeyPathType: NSTableColumn!
    @IBOutlet var columnKeyPathValue: NSTableColumn!

    private var initialUserInfo: OrderedDictionary<String, String> = [:]
    private var userInfo: OrderedDictionary<String, String> {
        if let keyPaths = arrayController.content as? [AssociatedKeyPath] {
            return OrderedDictionary<String, String>(keyPaths.map({ $0.keyValuePairs })) { _, new in new }
        }
        return [:]
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        okBtn.isEnabled = false
        touchBarOkBtn.isEnabled = false

        undoToken = NotificationCenter.default.observe(
            name: NSNotification.Name.NSUndoManagerDidUndoChange,
            object: undoManager
        ) { [unowned self] noti in
            if noti.object as? UndoManager == self.undoManager {
                debugPrint(noti)
            }
        }
        redoToken = NotificationCenter.default.observe(
            name: NSNotification.Name.NSUndoManagerDidRedoChange,
            object: undoManager
        ) { [unowned self] noti in
            if noti.object as? UndoManager == self.undoManager {
                debugPrint(noti)
            }
        }
        
        updateArrayControllerEditableState()
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        undoManager?.disableUndoRegistration()
        initialUserInfo.merge(populateInitialTable()) { _, new in new }
        undoManager?.enableUndoRegistration()
        
        updateArrayControllerEditableState()
    }
    
    private func updateArrayControllerEditableState() {
        arrayController.isEditable = isEditable
        box.title = isEditable ? NSLocalizedString("Edit Associated Values", comment: "updateArrayControllerEditableState()") : NSLocalizedString("View Associated Values", comment: "updateArrayControllerEditableState()")
    }

    private func populateInitialTable() -> OrderedDictionary<String, String> {
        var initial = OrderedDictionary<String, String>()
        if let contentItem = contentItem {
            if let tagManager = tagManager,
               let tagString = contentItem.firstTag,
               let tag = tagManager.managedTag(of: tagString),
               let tagFields = tag.fields.array as? [Field]
            {
                var keyPaths: [AssociatedKeyPath] = tagFields.map { tagField in
                    var contentValue: Any?
                    let tagName = tagField.name
                    let tagHelpText = tagField.helpText
                    let valueType = tagField.stringValueType ?? .String
                    switch valueType {
                    case .String:
                        contentValue = contentItem.userInfoValue(forKey: tagName, ofType: String.self) ?? tagField.toDefaultValue(ofType: String.self)
                    case .Boolean:
                        contentValue = contentItem.userInfoValue(forKey: tagName, ofType: Bool.self) ?? tagField.toDefaultValue(ofType: Bool.self)
                    case .Integer:
                        contentValue = contentItem.userInfoValue(forKey: tagName, ofType: Int.self) ?? tagField.toDefaultValue(ofType: Int.self)
                    case .Decimal:
                        contentValue = contentItem.userInfoValue(forKey: tagName, ofType: Double.self) ?? tagField.toDefaultValue(ofType: Double.self)
                    default:
                        break
                    }
                    let enumValueType = AssociatedKeyPath.ValueType(string: valueType)
                    let tagOptions = tagField.options.array.compactMap({ $0 as? FieldOption }).map({ $0.name })
                    let keyPath = AssociatedKeyPath(
                        name: tagName,
                        type: enumValueType,
                        value: contentValue,
                        options: tagOptions,
                        helpText: tagHelpText
                    )
                    return keyPath
                }

                let keyPathNames = keyPaths.map({ $0.name })
                if let userInfo = contentItem.userInfo {
                    initial.merge(userInfo) { _, new in new }
                    keyPaths += userInfo
                        .map({ AssociatedKeyPath(name: $0.key, type: .String, value: $0.value) })
                        .filter({ !keyPathNames.contains($0.name) })
                }

                shouldSkipContentArrayEvents = true
                arrayController.contentUpdateType = .direct
                arrayController.content = NSMutableArray(array: keyPaths)
                keyPaths.forEach({ $0.resetDynamicVariables() })
                initial.merge(OrderedDictionary<String, String>(keyPaths.map({ $0.keyValuePairs })) { _, new in new }) { _, new in new }
                shouldSkipContentArrayEvents = false
            } else {
                var keyPaths = [AssociatedKeyPath]()
                if let userInfo = contentItem.userInfo {
                    initial.merge(userInfo) { _, new in new }
                    keyPaths += userInfo
                        .map({ AssociatedKeyPath(name: $0.key, type: .String, value: $0.value) })
                }
                shouldSkipContentArrayEvents = true
                arrayController.contentUpdateType = .direct
                arrayController.content = NSMutableArray(array: keyPaths)
                keyPaths.forEach({ $0.resetDynamicVariables() })
                initial.merge(OrderedDictionary<String, String>(keyPaths.map({ $0.keyValuePairs })) { _, new in new }) { _, new in new }
                shouldSkipContentArrayEvents = false
            }
        }
        return initial
    }

    private var shouldSkipContentArrayEvents: Bool = false
    private var cachedArraySelectionIndexes: IndexSet?
    private var cachedArrayContent: [AssociatedKeyPath]?
    private var cachedArrayUpdateType: EditArrayControllerUpdateType?

    func contentArrayWillUpdate(_ sender: EditArrayController, type: EditArrayControllerUpdateType) {
        guard !shouldSkipContentArrayEvents else { return }
        cachedArraySelectionIndexes = sender.selectionIndexes
        cachedArrayContent = (sender.content as? [AssociatedKeyPath])?.compactMap({ $0.copy() as? AssociatedKeyPath })
        cachedArrayUpdateType = type
    }

    func contentArrayDidUpdate(_ sender: EditArrayController, type: EditArrayControllerUpdateType) {
        guard !shouldSkipContentArrayEvents else { return }
        guard let cachedArraySelectionIndexes = cachedArraySelectionIndexes,
              let cachedArrayContent = cachedArrayContent,
              let cachedArrayUpdateType = cachedArrayUpdateType
        else {
            return
        }
        undoManager?.registerUndo(withTarget: self, handler: { target in
            target.arrayController.contentUpdateType = cachedArrayUpdateType
            target.arrayController.content = NSMutableArray(array: cachedArrayContent)
            cachedArrayContent.forEach({ $0.resetDynamicVariables() })
            target.arrayController.setSelectionIndexes(cachedArraySelectionIndexes)
        })
        switch cachedArrayUpdateType {
        case .add, .insert:
            undoManager?.setActionName(NSLocalizedString("Add Associated Values", comment: "contentArrayDidUpdate(_:)"))
        case .remove:
            undoManager?.setActionName(NSLocalizedString("Remove Associated Values", comment: "contentArrayDidUpdate(_:)"))
        case .update, .direct:
            undoManager?.setActionName(NSLocalizedString("Edit Associated Values", comment: "contentArrayDidUpdate(_:)"))
        }
        updateOKButtonState()
    }
    
    func tableView(_ tableView: NSTableView, typeSelectStringFor tableColumn: NSTableColumn?, row: Int) -> String? {
        guard let tableColumn = tableColumn, row < arrangedAssociatedKeyPaths.count else { return nil }
        if tableColumn == columnKeyPathName {
            return arrangedAssociatedKeyPaths[row].name
        }
        return nil
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn else {
            return nil
        }
        guard let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: tableView.delegate) as? EditAssociatedValuesTableViewCell else {
            return nil
        }
        cell.isEditable = isEditable
        return cell
    }
    
    func tableView(_ tableView: NSTableView, shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool {
        return isEditable
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(delete(_:)) {
            return isEditable && arrayController.selectionIndexes.count > 0
        }
        return false
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        menu.items.forEach({
            $0.isEnabled = $0.state == .on || isEditable
        })
    }

    @IBAction func delete(_ sender: Any) {
        arrayController.remove(sender)
    }

    @IBAction private func cancelAction(_ sender: NSButton) {
        guard let window = view.window, let parent = window.sheetParent else { return }
        parent.endSheet(window, returnCode: .cancel)
    }

    @IBAction private func okAction(_ sender: NSButton) {
        guard let delegate = contentDelegate else { return }
        guard let window = view.window, let parent = window.sheetParent else { return }
        do {
            if let updatedItem = contentItem?.copy() as? ContentItem {
                updatedItem.userInfo = userInfo
                if let _ = try delegate.updateContentItem(updatedItem) {
                    parent.endSheet(window, returnCode: .OK)
                }
            }
        } catch {
            presentError(error)
        }
    }

    private func updateOKButtonState() {
        isOKButtonEnabled = isEditable && initialUserInfo != userInfo
    }

    private var isOKButtonEnabled: Bool {
        get {
            okBtn.isEnabled
        }
        set {
            okBtn.isEnabled = newValue
            touchBarOkBtn.isEnabled = newValue
        }
    }

    deinit {
        debugPrint("\(className):\(#function)")
    }
}
