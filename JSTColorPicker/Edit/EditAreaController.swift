//
//  EditAreaController.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/6/5.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class EditAreaController: EditViewController {

    @IBOutlet weak var cancelBtn    : NSButton!
    @IBOutlet weak var okBtn        : NSButton!
    @IBOutlet weak var fixedRatioBtn: NSButton!
    
    @IBOutlet weak var textFieldOriginX  : NSTextField!
    @IBOutlet weak var textFieldOriginY  : NSTextField!
    @IBOutlet weak var textFieldWidth    : NSTextField!
    @IBOutlet weak var textFieldHeight   : NSTextField!
    @IBOutlet weak var textFieldOppositeX: NSTextField!
    @IBOutlet weak var textFieldOppositeY: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction private func validateInputs(_ sender: NSTextField) {
        
    }
    
    @IBAction private func cancelAction(_ sender: NSButton) {
        guard let window = view.window else { return }
        guard let parent = window.sheetParent else { return }
        parent.endSheet(window, returnCode: .cancel)
    }
    
    @IBAction private func okAction(_ sender: NSButton) {
        guard let window = view.window else { return }
        guard let parent = window.sheetParent else { return }
        parent.endSheet(window, returnCode: .OK)
    }
    
}
