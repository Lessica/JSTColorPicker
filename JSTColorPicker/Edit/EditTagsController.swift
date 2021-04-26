//
//  EditTagsController.swift
//  JSTColorPicker
//
//  Created by Darwin on 6/29/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class EditTagsController: EditViewController {
    
    @IBOutlet weak var box          : NSBox!
    
    @IBOutlet weak var cancelBtn    : NSButton!
    @IBOutlet weak var okBtn        : NSButton!
    
    @IBOutlet weak var touchBarCancelBtn    : NSButton!
    @IBOutlet weak var touchBarOkBtn        : NSButton!
    
    var tagListController: TagListController! {
        return children.first as? TagListController
    }
    
    private var cachedTagNames: [String] = []
    private var cachedTagStates: [String: NSControl.StateValue] = [:]
    private var _alternateState: NSControl.StateValue = .off
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        okBtn.isEnabled = false
        touchBarOkBtn.isEnabled = false
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        guard segue.identifier == "TagListContainerEmbed",
            let controller = segue.destinationController as? TagListController else
        { return }
        
        controller.editDelegate = self
    }
    
    @IBAction private func cancelAction(_ sender: NSButton) {
        guard let window = view.window, let parent = window.sheetParent else { return }
        parent.endSheet(window, returnCode: .cancel)
    }
    
    @IBAction private func okAction(_ sender: NSButton) {
        guard let delegate = contentDelegate else { return }
        guard let window = view.window, let parent = window.sheetParent else { return }
        do {
            
            let onTagNames =
                cachedTagNames
                    .filter({ cachedTagStates[$0] == .on })
            
            let offTagNames = Set(
                cachedTagNames
                    .filter({ cachedTagStates[$0] == .off })
            )
            
            if let origItems = contentItems {
                var replItems = [ContentItem]()
                
                for origItem in origItems {
                    let origTags = origItem.tags
                    
                    var replTags = OrderedSet(origTags.filter({ !offTagNames.contains($0) }))
                    replTags.append(contentsOf: onTagNames)
                    
                    let replItem = origItem.copy() as! ContentItem
                    replItem.tags = replTags
                    replItems.append(replItem)
                }
                
                if let _ = try delegate.updateContentItems(replItems) {
                    parent.endSheet(window, returnCode: .OK)
                }
            }
            
        } catch {
            presentError(error)
        }
    }
    
}

extension EditTagsController: TagListEditDelegate {
    
    var alternateState: NSControl.StateValue {
        get {
            _alternateState
        }
        set {
            _alternateState = newValue
        }
    }
    
    func editState(of name: String) -> NSControl.StateValue {
        if let cachedState = cachedTagStates[name] {
            return cachedState
        }
        let newState = internalStateOfTag(of: name)
        cachedTagNames.append(name)
        cachedTagStates[name] = newState
        return newState
    }
    
    private func internalStateOfTag(of name: String) -> NSControl.StateValue {
        guard let contentItems = contentItems else { return .off }
        let matchesCount = contentItems
            .lazy
            .filter({ $0.tags.contains(name) })
            .count
        guard matchesCount > 0 else { return .off }
        return matchesCount == contentItems.count ? .on : .mixed
    }
    
    func editStateChanged(of name: String, to state: NSControl.StateValue) {
        cachedTagStates[name] = state
        okBtn.isEnabled = true
        touchBarOkBtn.isEnabled = true
        debugPrint(cachedTagStates)
    }
    
}

