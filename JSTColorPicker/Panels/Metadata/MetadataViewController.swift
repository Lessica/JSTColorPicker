//
//  MetadataViewController.swift
//  JSTColorPicker
//
//  Created by Darwin on 2022/3/26.
//  Copyright © 2022 JST. All rights reserved.
//

import Cocoa
import LNPropertyListEditor

final class MetadataViewController: NSViewController, LNPropertyListEditorDelegate, LNPropertyListEditorDataTransformer {
    
    var metadataWindow: MetadataWindow? { view.window as? MetadataWindow }
    var screenshot: Screenshot? { metadataWindow?.loader?.screenshot }
    var isEditable: Bool = false
    
    @IBOutlet weak var editor: MetadataEditor!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        editor.delegate = self
        editor.dataTransformer = self
        
        loadMetadataObject()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        loadMetadataObject()
    }
    
    private func loadMetadataObject() {
        if let metadata = screenshot?.viewableMetadata {
            editor.propertyListObject = metadata
            editor.allowsColumnSorting = false
        }
    }
    
    @IBAction private func closeAction(_ sender: NSButton) {
        guard let window = view.window, let parent = window.sheetParent else { return }
        parent.endSheet(window, returnCode: .cancel)
    }
    
    func propertyListEditor(_ editor: LNPropertyListEditor, displayNameFor node: LNPropertyListNode) -> String? {
        if node.key?.uppercased() == "ID" {
            return "ID"
        }
        else if node.key?.uppercased() == "USERINFO" {
            return "UserInfo"
        }
        else if node.key?.first?.isLowercase ?? false {
            return node.key?.localizedCapitalized
        }
        return node.key
    }
    
    func propertyListEditor(_ editor: LNPropertyListEditor, canEditKeyOf node: LNPropertyListNode) -> Bool {
        return isEditable
    }
    
    func propertyListEditor(_ editor: LNPropertyListEditor, canEditTypeOf node: LNPropertyListNode) -> Bool {
        return isEditable
    }
    
    func propertyListEditor(_ editor: LNPropertyListEditor, canEditValueOf node: LNPropertyListNode) -> Bool {
        return isEditable
    }
    
    func propertyListEditor(_ editor: LNPropertyListEditor, canAddChildNodeIn node: LNPropertyListNode) -> Bool {
        return isEditable
    }
    
    func propertyListEditor(_ editor: LNPropertyListEditor, canDelete node: LNPropertyListNode) -> Bool {
        return isEditable
    }
    
    func propertyListEditor(_ editor: LNPropertyListEditor, canMove movedNode: LNPropertyListNode, toParentNode parentNode: LNPropertyListNode, at index: Int) -> Bool {
        return isEditable
    }
    
    func propertyListEditor(_ editor: LNPropertyListEditor, canPaste pastedNode: LNPropertyListNode, asChildOf node: LNPropertyListNode) -> Bool {
        return isEditable
    }
}
