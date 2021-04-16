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

final class ReadWriteLock {
    private var rwlock: pthread_rwlock_t = {
        var rwlock = pthread_rwlock_t()
        pthread_rwlock_init(&rwlock, nil)
        return rwlock
    }()

    func writeLock() {
        pthread_rwlock_wrlock(&rwlock)
    }

    func readLock() {
        pthread_rwlock_rdlock(&rwlock)
    }

    func unlock() {
        pthread_rwlock_unlock(&rwlock)
    }

    deinit {
        pthread_rwlock_destroy(&rwlock)
    }
}

class TemplatePreviewController: StackedPaneController {
    
    override var menuIdentifier: NSUserInterfaceItemIdentifier { NSUserInterfaceItemIdentifier("show-template-preview") }

    @IBOutlet weak var timerButton        : NSButton!
    @IBOutlet weak var outlineView        : NSOutlineView!
    @IBOutlet weak var emptyOutlineLabel  : NSTextField!
    @IBOutlet      var outlineMenu        : NSMenu!

    @IBAction func timerButtonTapped(_ sender: NSButton) {
        // TODO: preview selected items only
    }

    override func load(_ screenshot: Screenshot) throws {
        try super.load(screenshot)
        prepareAll()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateViewState()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(templatesDidLoad(_:)),
            name: TemplateManager.NotificationType.Name.templatesDidLoadNotification,
            object: nil
        )
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


    // MARK: - Templates

    private var previewableTemplates: [Template] { TemplateManager.shared.previewableTemplates }

    private func templateWithUUIDString(_ uuidString: String) -> Template? {
        let template = TemplateManager.shared.templateWithUUIDString(uuidString)
        guard template?.isPreviewable ?? false else { return nil }
        return template
    }


    // MARK: - Contents

    private var cachedPreviewContents: [String: String] = [:]
    private let cachingQueue = DispatchQueue(label: "CachedPreviewContents.Queue", attributes: .concurrent)
    private let cachingLock = ReadWriteLock()
    private var isCaching: Bool = false

    private func prepareAllContentItemsForTemplate(_ template: Template, in group: DispatchGroup) {
        guard let exportManager = screenshot?.export else { return }
        group.enter()
        self.cachingQueue.async { [weak self] in
            guard let self = self else {
                group.leave()
                return
            }
            var displayString: String
            do {
                displayString = try exportManager.generateAllContentItems(with: template)
            } catch {
                displayString = error.localizedDescription
            }
            self.cachingLock.writeLock()
            self.cachedPreviewContents[template.uuid.uuidString] = displayString
            self.cachingLock.unlock()
            group.leave()
        }
    }

    private func prepareAll() /* prepareAllContentItemsForAllPreviewableTemplates */ {
        guard !isCaching else { return }
        self.isCaching = true
        // TODO: store expanded item states, reload these items only, expand original items again.
        let group = DispatchGroup()
        self.previewableTemplates.forEach { template in
            self.prepareAllContentItemsForTemplate(template, in: group)
        }
        group.notify(queue: .main) { [weak self] in
            self?.outlineView.reloadData()
            self?.isCaching = false
        }
    }

}

extension TemplatePreviewController: NSMenuItemValidation, NSMenuDelegate {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        return true
    }

    // TODO: implementation
}

extension TemplatePreviewController: NSOutlineViewDataSource, NSOutlineViewDelegate {

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        return item == nil ? previewableTemplates.count : 1
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return item is Template
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return previewableTemplates[index]
        } else if let template = item as? Template
        {
            var displayString: String
            cachingLock.readLock()
            displayString = self.cachedPreviewContents[template.uuid.uuidString] ?? NSLocalizedString("Generating...", comment: "Outline Generation")
            cachingLock.unlock()
            return displayString
        }
        return NSLocalizedString("Document not loaded.", comment: "Outline Generation")
    }

    func outlineView(_ outlineView: NSOutlineView, persistentObjectForItem item: Any?) -> Any? {
        return (item as? Template)?.uuid.uuidString ?? nil
    }

    func outlineView(_ outlineView: NSOutlineView, itemForPersistentObject object: Any) -> Any? {
        if let templateUUID = object as? String {
            return templateWithUUIDString(templateUUID)
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

}

extension TemplatePreviewController {
    
    @objc private func templatesDidLoad(_ noti: Notification) {
        updateViewState()
        prepareAll()
    }
    
}
