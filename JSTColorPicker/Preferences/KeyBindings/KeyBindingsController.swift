//
//  KeyBindingsController.swift
//
//  CotEditor
//  https://coteditor.com
//
//  Created by 1024jp on 2014-08-20.
//
//  ---------------------------------------------------------------------------
//
//  © 2014-2020 1024jp
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Cocoa
import MASPreferences

/// outilneView column identifier
private extension NSUserInterfaceItemIdentifier {
    
    static let title = NSUserInterfaceItemIdentifier("title")
    static let keySpecChars = NSUserInterfaceItemIdentifier("keyBindingKey")
}


class KeyBindingsController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate, NSTextFieldDelegate {
    
    // MARK: Private Properties
    
    private var outlineTree: [NSTreeNode] = []
    @objc private dynamic var warningMessage: String?  // for binding
    @objc private dynamic var isRestoreble: Bool = false  // for binding
    
    @IBOutlet fileprivate weak var outlineView: NSOutlineView?
    
    
    // MARK: Initializer
    
    init() {
        super.init(nibName: "KeyBindings", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK: -
    // MARK: View Controller Methods
    
    override func viewWillAppear() {
        
        super.viewWillAppear()
        
        self.outlineTree = self.manager.outlineTree(defaults: false)
        self.isRestoreble = !self.manager.usesDefaultKeyBindings
        self.outlineView?.reloadData()
    }
    
    
    /// finish current editing
    override func viewWillDisappear() {
        
        super.viewWillDisappear()
        
        self.endEditing()
    }
    
    
    
    // MARK: Outline View Data Source
    
    /// return number of child items
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        
        return self.children(of: item)?.count ?? 0
    }
    
    
    /// return if item is expandable
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        
        return (self.children(of: item) != nil)
    }
    
    
    /// return child items
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        
        return self.children(of: item)![index]
    }
    
    
    /// auto-expand save
    func outlineView(_ outlineView: NSOutlineView, persistentObjectForItem item: Any?) -> Any? {
        if let node = item as? NamedTreeNode {
            return node.name
        }
        return nil
    }
    
    
    /// auto-expand restore
    func outlineView(_ outlineView: NSOutlineView, itemForPersistentObject object: Any) -> Any? {
        if let nodeName = object as? String {
            // only top-level nodes
            return self.outlineTree
                .compactMap({ $0 as? NamedTreeNode })
                .first(where: { $0.name == nodeName })
        }
        return nil
    }
    
    
    /// return suitable item for cell to display
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        
        guard
            let identifier = tableColumn?.identifier,
            let node = item as? NamedTreeNode
            else { return "" }
        
        switch identifier {
            case .title:
                return node.name
            
            case .keySpecChars:
                guard let shortcut = (node.representedObject as? KeyBindingItem)?.shortcut, shortcut.isValid else { return nil }
                return shortcut.isValid ? shortcut.description : nil
            
            default:
                return ""
        }
    }
    
    
    
    // MARK: Outline View Delegate
    
    /// initialize table cell view
    func outlineView(_ outlineView: NSOutlineView, didAdd rowView: NSTableRowView, forRow row: Int) {
        
        if let view = rowView.view(atColumn: outlineView.column(withIdentifier: .keySpecChars)) as? NSTableCellView,
            let textField = view.textField,
            let node = outlineView.item(atRow: row) as? NSTreeNode
        {
            let keyBinding = node.representedObject as? KeyBindingItem
            
            // set if table cell is editable
            textField.isEditable = (keyBinding != nil)
            
            // set default short cut to placeholder
            textField.placeholderString = keyBinding?.defaultShortcut.description
        }
    }
    
    
    
    // MARK: Text Field Delegate
    // (outlineView->ShortcutKeyField)
    
    /// validate and apply new shortcut key input
    func controlTextDidEndEditing(_ obj: Notification) {
        
        guard
            let textField = obj.object as? NSTextField,
            let outlineView = self.outlineView
            else { return assertionFailure() }
        
        let row = outlineView.row(for: textField)
        let column = outlineView.column(for: textField)
        
        guard
            let node = outlineView.item(atRow: row) as? NSTreeNode, node.isLeaf,
            let item = node.representedObject as? KeyBindingItem
            else { return }
        
        let oldShortcut = item.shortcut
        let input = textField.stringValue
        
        // reset once warning
        self.warningMessage = nil
        
        // cancel input
        guard
            input != "\u{1b}",  // = ESC key  -> treat esc key as cancel
            input != item.shortcut?.description  // not edited
            else {
                // reset text field display
                textField.objectValue = oldShortcut?.description
                return
            }
        
        let shortcut = Shortcut(keySpecChars: input)
        
        do {
            try self.manager.validate(shortcut: shortcut, oldShortcut: oldShortcut)
            
        } catch let error as InvalidKeySpecCharactersError {
            self.warningMessage = error.localizedDescription + " " + (error.recoverySuggestion ?? "")
            textField.objectValue = oldShortcut?.keySpecChars  // reset view with previous key
            NSSound.beep()
            
            // make text field edit mode again if invalid
            DispatchQueue.main.async {
                outlineView.editColumn(column, row: row, with: nil, select: true)
            }
            // reset text field display
            textField.objectValue = oldShortcut?.description
            return
            
        } catch { assertionFailure("Caught unknown error.") }
        
        // successfully update data
        item.shortcut = shortcut
        textField.objectValue = shortcut.description
        self.saveSettings()
        self.outlineView?.reloadData(forRowIndexes: [row], columnIndexes: [column])
    }
    
    
    
    // MARK: Action Messages
    
    /// restore key binding setting to default
    @IBAction func setToFactoryDefaults(_ sender: Any?) {
        
        self.outlineTree = self.manager.outlineTree(defaults: true)
        
        self.saveSettings()
        
        self.outlineView?.deselectAll(nil)
        self.outlineView?.reloadData()
        self.warningMessage = nil
        self.isRestoreble = false
    }
    
    
    
    // MARK: Private Methods
    
    /// corresponding key binding manager
    fileprivate var manager: KeyBindingManager {
        
        return MenuKeyBindingManager.shared
    }
    
    
    /// return child items of passed-in item
    private func children(of item: Any?) -> [NSTreeNode]? {
        
        guard let node = item as? NSTreeNode else { return self.outlineTree }
        
        return node.isLeaf ? nil : node.children
    }
    
    
    /// save current settings
    fileprivate func saveSettings() {
        
        do {
            try self.manager.saveKeyBindings(outlineTree: self.outlineTree)
        } catch {
            Swift.print(error)
        }
        
        self.isRestoreble = !self.manager.usesDefaultKeyBindings
    }
    
}

extension KeyBindingsController: MASPreferencesViewController {
    
    var hasResizableWidth: Bool {
        return false
    }
    
    var hasResizableHeight: Bool {
        return false
    }
    
    var viewIdentifier: String {
        return "KeyBindingsPreferences"
    }
    
    var toolbarItemLabel: String? {
        return NSLocalizedString("Key Bindings", comment: "toolbarItemLabel")
    }
    
    var toolbarItemImage: NSImage? {
        return NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KeyBindings")
    }
    
}


private extension NSWindow {
    
    /// end current editing and restore the current responder afterwards
    @discardableResult
    func endEditing() -> Bool {
        
        let responder: NSResponder?
        if let editor = self.firstResponder as? NSTextView, editor.isFieldEditor {
            // -> Regarding field editors, the real first responder is its delegate.
            responder = editor.delegate as? NSResponder
        } else {
            responder = self.firstResponder
        }
        
        let sucsess = self.makeFirstResponder(nil)
        
        // restore current responder
        if sucsess, let responder = responder {
            self.makeFirstResponder(responder)
        }
        
        return sucsess
    }
    
}


private extension NSViewController {
    
    /// end current editing and restore the current responder afterwards
    @discardableResult
    func endEditing() -> Bool {
        
        guard self.isViewLoaded else { return true }
        
        return self.view.window?.endEditing() ?? false
    }
    
}
