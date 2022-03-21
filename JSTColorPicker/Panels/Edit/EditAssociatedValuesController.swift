//
//  EditAssociatedValuesController.swift
//  JSTColorPicker
//
//  Created by Darwin on 6/29/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

final class EditAssociatedValuesController: EditViewController {
    
    @IBOutlet weak var box          : NSBox!
    @IBOutlet weak var tableView    : NSTableView!
    
    @IBOutlet weak var cancelBtn    : NSButton!
    @IBOutlet weak var okBtn        : NSButton!
    
    @IBOutlet weak var touchBarCancelBtn    : NSButton!
    @IBOutlet weak var touchBarOkBtn        : NSButton!
    
    var tagListController: TagListController! {
        return children.first as? TagListController
    }
    
    private var cachedTagNames   = Set<String>()
    private var cachedTagStates  : [String: NSControl.StateValue] = [:]
    private var initialTagStates : [String: NSControl.StateValue]?
    private var _alternateState  : NSControl.StateValue = .off
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        okBtn.isEnabled = false
        touchBarOkBtn.isEnabled = false
    }
    
    @IBAction private func cancelAction(_ sender: NSButton) {
        guard let window = view.window, let parent = window.sheetParent else { return }
        parent.endSheet(window, returnCode: .cancel)
    }
    
    @IBAction private func okAction(_ sender: NSButton) {
        
    }
    
}
