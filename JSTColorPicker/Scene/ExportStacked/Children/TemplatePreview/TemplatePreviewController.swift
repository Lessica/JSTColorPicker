//
//  TemplatePreviewController.swift
//  JSTColorPicker
//
//  Created by Rachel on 4/15/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

private extension NSUserInterfaceItemIdentifier {
    static let columnName  = NSUserInterfaceItemIdentifier("col-name")
}

class TemplatePreviewController: StackedPaneController {

    @IBOutlet weak var timerButton: NSButton!
    @IBOutlet weak var outlineView: NSOutlineView!

    @IBAction func timerButtonTapped(_ sender: NSButton) {
        
    }

    override func load(_ screenshot: Screenshot) throws {
        try super.load(screenshot)
    }

}

extension TemplatePreviewController: NSOutlineViewDataSource, NSOutlineViewDelegate {

    private var previewableTemplates: [Template] { TemplateManager.shared.previewableTemplates }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return previewableTemplates.count
        } else {
            return 1
        }
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if item is Template {
            return true
        }
        return false
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return previewableTemplates[index]
        } else {
            return ""
        }
    }

    func outlineView(_ outlineView: NSOutlineView, persistentObjectForItem item: Any?) -> Any? {
        if let template = item as? Template {
            return template.uuid.uuidString
        }
        return nil
    }

    func outlineView(_ outlineView: NSOutlineView, itemForPersistentObject object: Any) -> Any? {
        if let templateUUID = object as? String {
            return previewableTemplates.first(where: { $0.uuid.uuidString == templateUUID })
        }
        return nil
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let tableColumn = tableColumn else { return nil }
        if let cell = outlineView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as? TemplateCellView {
            let col = tableColumn.identifier
            if col == .columnName, let template = item as? Template {
                cell.text = template.name
            }
            return cell
        }
        return nil
    }

}
