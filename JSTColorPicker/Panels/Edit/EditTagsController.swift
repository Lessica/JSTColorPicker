//
//  EditTagsController.swift
//  JSTColorPicker
//
//  Created by Darwin on 6/29/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa
import OrderedCollections

final class EditTagsController: EditViewController {
    
    @IBOutlet weak var box          : NSBox!
    
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
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        guard segue.identifier == "TagListContainerEmbed",
            let controller = segue.destinationController as? TagListController else
        { return }
        
        controller.selectDelegate = self
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
                    
                    if let tagManager = tagManager,
                       let firstTag = replItem.firstTag,
                       let firstUserInfo = tagManager.managedTag(of: firstTag)?.defaultUserInfo
                    {
                        var combinedUserInfo = replItem.userInfo ?? [:]
                        combinedUserInfo.merge(firstUserInfo) { old, _ in old }
                        replItem.userInfo = combinedUserInfo
                    }
                    
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
    
    deinit {
        debugPrint("\(className):\(#function)")
    }
    
}

extension EditTagsController: TagListSelectDelegate {
    
    func fetchAlternateStateForTags(_ tags: [Tag]) -> NSControl.StateValue {
        let allCount = tags.count
        var onCount = 0
        var offCount = 0
        var mixedCount = 0
        for state in tags.map({ selectedState(of: $0.name) }) {
            switch state {
            case .on:
                onCount += 1
            case .off:
                offCount += 1
            case .mixed:
                mixedCount += 1
            default:
                break
            }
        }
        if initialTagStates == nil {
            initialTagStates = cachedTagStates
        }
        if onCount == allCount {
            return .on
        }
        else if offCount == allCount {
            return .off
        }
        else {
            return .mixed
        }
    }
    
    func setupAlternateState(_ state: NSControl.StateValue, forTags tags: [Tag]) {
        let allTagNames = tags.map({ $0.name })
        selectedStatesChanged(Dictionary(allTagNames.map({ ($0, state) })) { _, new in new })
    }
    
    func selectedState(of name: String) -> NSControl.StateValue {
        if let cachedState = cachedTagStates[name] {
            return cachedState
        }
        let newState = internalStateOfTag(of: name)
        cachedTagNames.insert(name)
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
    
    func selectedStateChanged(of name: String, to state: NSControl.StateValue) {
        if let originalState = cachedTagStates[name] {
            let currentSelectedIndexSet = tagListController.selectedRowIndexes
            undoManager?.registerUndo(withTarget: self, handler: { (target) in
                target.tagListController.internalSetDeferredSelection(currentSelectedIndexSet)
                target.selectedStateChanged(of: name, to: originalState)
            })
            undoManager?.setActionName(NSLocalizedString("Choose Tags", comment: "selectedStateChanged(of:to:)"))
        }
        cachedTagNames.insert(name)
        cachedTagStates[name] = state
        updateOKButtonState()
        debugPrint(cachedTagStates)
    }
    
    func selectedStatesChanged(_ states: [String: NSControl.StateValue]) {
        let originalStates = cachedTagStates
        let currentSelectedIndexSet = tagListController.selectedRowIndexes
        undoManager?.registerUndo(withTarget: self, handler: { (target) in
            target.tagListController.internalSetDeferredSelection(currentSelectedIndexSet)
            target.selectedStatesChanged(originalStates)
        })
        undoManager?.setActionName(NSLocalizedString("Choose Tags", comment: "selectedStatesChanged(_:)"))
        cachedTagNames.formUnion(states.keys)
        cachedTagStates.merge(states) { _, new in new }
        updateOKButtonState()
        debugPrint(cachedTagStates)
    }
    
    private func updateOKButtonState() {
        isOKButtonEnabled = initialTagStates != cachedTagStates
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
    
}
