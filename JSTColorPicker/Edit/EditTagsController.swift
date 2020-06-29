//
//  EditTagsController.swift
//  JSTColorPicker
//
//  Created by Darwin on 6/29/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class EditTagsController: NSViewController {
    
    public var tagListController: TagListController! {
        return children.first as? TagListController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        guard segue.identifier == "TagListContainerEmbed",
            let controller = segue.destinationController as? TagListController else
        { return }
        
        controller.embeddedDelegate = self
    }
    
    @IBAction private func cancelAction(_ sender: NSButton) {
        guard let window = view.window, let parent = window.sheetParent else { return }
        parent.endSheet(window, returnCode: .cancel)
    }
    
    @IBAction private func okAction(_ sender: NSButton) {
        
    }
    
}

extension EditTagsController: TagListEmbedDelegate {
    
}

