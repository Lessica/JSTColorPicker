//
//  TemplatePreviewController.swift
//  JSTColorPicker
//
//  Created by Rachel on 4/15/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

private extension NSUserInterfaceItemIdentifier {
    static let columnName = NSUserInterfaceItemIdentifier("col-name")
}

private extension NSUserInterfaceItemIdentifier {
    static let cellTemplate         = NSUserInterfaceItemIdentifier("cell-template")
    static let cellTemplateContent  = NSUserInterfaceItemIdentifier("cell-template-content")
}

class TemplatePreviewController: StackedPaneController {
    
    override var menuIdentifier: NSUserInterfaceItemIdentifier { NSUserInterfaceItemIdentifier("show-template-preview") }

    @IBOutlet weak var timerButton        : NSButton!
    @IBOutlet weak var outlineView        : NSOutlineView!
    @IBOutlet weak var emptyOutlineLabel  : NSTextField!

    @IBAction func timerButtonTapped(_ sender: NSButton) {
        
    }

    override func load(_ screenshot: Screenshot) throws {
        try super.load(screenshot)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(templatesDidLoad(_:)),
            name: TemplateManager.NotificationType.Name.templatesDidLoadNotification,
            object: nil
        )
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateViewState()
    }
    
    private func updateViewState() {
        if previewableTemplates.isEmpty {
            outlineView.isEnabled = false
            emptyOutlineLabel.isHidden = false
        } else {
            outlineView.isEnabled = true
            emptyOutlineLabel.isHidden = true
        }
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
            return """
x, y = screen.find_color({
  {  252,  317, 0x52a0fb,  90.00 },  -- 1
})
"""
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
        let col = tableColumn.identifier
        if col == .columnName {
            if let template = item as? Template, let cell = outlineView.makeView(withIdentifier: .cellTemplate, owner: nil) as? TemplateCellView {
                cell.text = template.name
                return cell
            }
            else if let templateContent = item as? String, let cell = outlineView.makeView(withIdentifier: .cellTemplateContent, owner: nil) as? TemplateContentCellView {
                cell.text = templateContent
                return cell
            }
        }
        return nil
    }
    
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        if item is Template {
            return 16
        } else {
            return 80
        }
    }

}

extension TemplatePreviewController {
    
    @objc private func templatesDidLoad(_ noti: Notification) {
        updateViewState()
        outlineView.reloadData()
    }
    
}
