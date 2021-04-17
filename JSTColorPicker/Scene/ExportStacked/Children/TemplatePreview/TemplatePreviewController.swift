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

struct TemplatePreviewObject {
    let content: String?
    let error: String?
    var hasError: Bool { error != nil }
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
        backupExpandedState()
        try super.load(screenshot)
        processPreviewContext()
        
        NotificationCenter.default.removeObserver(
            self,
            name: MainWindow.VisibilityDidChangeNotification,
            object: view.window
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowVisibilityDidChange(_:)),
            name: MainWindow.VisibilityDidChangeNotification,
            object: view.window
        )
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateViewState()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(templatesWillLoad(_:)),
            name: TemplateManager.NotificationType.Name.templatesWillLoadNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(templatesDidLoad(_:)),
            name: TemplateManager.NotificationType.Name.templatesDidLoadNotification,
            object: nil
        )
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        processPreviewContextIfNeeded()
    }
    
    @objc private func windowVisibilityDidChange(_ noti: Notification) {
        processPreviewContextIfNeeded()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - Context
    
    private var _shouldProcessContext : Bool = false
    
    private func setNeedsProcessContext() {
        _shouldProcessContext = true
    }
    
    private func processPreviewContextIfNeeded() {
        if _shouldProcessContext {
            _shouldProcessContext = false
            processPreviewContext()
        }
    }
    
    private func processPreviewContext() {
        guard !isPaneHidden && !isWindowHidden else {
            _shouldProcessContext = true
            return
        }
        guard !isProcessing else { return }
        
        updateViewState()
        clearContentsForAllTemplates()
        
        isExpanding = true
        outlineView.reloadData()
        let templatesToReload = previewableTemplates
            .filter({ cachedExpandedState?.contains($0.uuid.uuidString) ?? false })
        DispatchQueue.main.async { [weak self] in
            self?.restoreExpandedState()
            self?.clearExpandedState()
            //isExpanding = false
        }
        
        isReloading = true
        prepareContentsForTemplates(
            templatesToReload,
            in: .main
        ) { [weak self] (template) in
            self?.outlineView.reloadItem(template, reloadChildren: true)
        } completionHandler: { [weak self] (finished) in
            self?.updateViewState()
            self?.isReloading = false
        }
    }


    // MARK: - Templates
    
    private var isProcessing           : Bool { isCaching || isReloading || isExpanding }

    private var previewableTemplates: [Template] { TemplateManager.shared.previewableTemplates }

    private func templateWithUUIDString(_ uuidString: String) -> Template? {
        let template = TemplateManager.shared.templateWithUUIDString(uuidString)
        guard template?.isPreviewable ?? false else { return nil }
        return template
    }
    
    
    // MARK: - View States
    
    private var isReloading            : Bool = false
    
    private func updateViewState() {
        if previewableTemplates.isEmpty {
            outlineView.isEnabled = false
            emptyOutlineLabel.isHidden = false
        } else {
            outlineView.isEnabled = true
            emptyOutlineLabel.isHidden = true
        }
    }
    
    private func reloadContentsForTemplates(_ templates: [Template]) {
        isReloading = true
        templates.forEach({ outlineView.reloadItem($0, reloadChildren: true) })
        isReloading = false
    }
    
    private func reloadContentsForTemplate(_ template: Template) {
        isReloading = true
        outlineView.reloadItem(template, reloadChildren: true)
        isReloading = false
    }


    // MARK: - Expanded States

    private var cachedExpandedState    : [String]?
    private var isExpanding            : Bool = false
    private var isCollapsing           : Bool = false
    
    private var currentExpandedState   : [String]
    {
        return previewableTemplates
            .filter({ outlineView.isItemExpanded($0) })
            .map({ $0.uuid.uuidString })
    }
    
    private func backupExpandedState() {
        cachedExpandedState = currentExpandedState
    }
    
    private func restoreExpandedState() {
        isExpanding = true
        cachedExpandedState?
            .compactMap({ templateWithUUIDString($0) })
            .filter({ outlineView.isExpandable($0) && !outlineView.isItemExpanded($0) })
            .forEach({ outlineView.expandItem($0) })
        isExpanding = false
    }
    
    private func clearExpandedState() {
        cachedExpandedState = nil
    }
    
    
    // MARK: - Preview Contents
    
    private var cachedPreviewContents  : [String: TemplatePreviewObject] = [:]
    private let cachingQueue           : DispatchQueue = DispatchQueue(label: "CachedPreviewContents.Queue", attributes: .concurrent)
    private let cachingLock            : ReadWriteLock = ReadWriteLock()
    private var isCaching              : Bool = false
    {
        didSet {
            outlineView.isEnabled = !isCaching
        }
    }
    
    private func clearContentsForTemplate(_ template: Template) {
        cachingLock.writeLock()
        cachedPreviewContents.removeValue(forKey: template.uuid.uuidString)
        cachingLock.unlock()
    }
    
    private func clearContentsForTemplates(_ templates: [Template]) {
        cachingLock.writeLock()
        templates.forEach({ cachedPreviewContents.removeValue(forKey: $0.uuid.uuidString) })
        cachingLock.unlock()
    }
    
    private func clearContentsForAllTemplates() {
        cachingLock.writeLock()
        cachedPreviewContents.removeAll()
        cachingLock.unlock()
    }
    
    private func clearContentsWithError() {
        cachingLock.writeLock()
        cachedPreviewContents = cachedPreviewContents.filter({ !$0.value.hasError })
        cachingLock.unlock()
    }
    
    private func prepareContentsForTemplate(_ template: Template, in group: DispatchGroup, completionHandler completion: @escaping (Template) -> Void) {
        guard let exportManager = screenshot?.export else { return }
        group.enter()
        cachingQueue.async { [weak self] in
            guard let self = self else {
                group.leave()
                return
            }
            
            var previewObj: TemplatePreviewObject
            do {
                previewObj = TemplatePreviewObject(
                    content: try exportManager.generateAllContentItems(with: template),
                    error: nil
                )
            } catch {
                previewObj = TemplatePreviewObject(
                    content: nil,
                    error: error.localizedDescription
                )
            }
            
            self.cachingLock.writeLock()
            self.cachedPreviewContents[template.uuid.uuidString] = previewObj
            self.cachingLock.unlock()
            
            completion(template)
            group.leave()
        }
    }
    
    private func prepareContentsForAllTemplates(
        in queue: DispatchQueue,
        callback: @escaping (Template) -> Void,
        completionHandler completion: @escaping (Bool) -> Void
    ) {
        prepareContentsForTemplates(previewableTemplates, in: queue, callback: callback, completionHandler: completion)
    }

    private func prepareContentsForTemplates(
        _ templates: [Template],
        in queue: DispatchQueue,
        callback: @escaping (Template) -> Void,
        completionHandler completion: @escaping (Bool) -> Void
    ) {
        guard !isCaching else {
            completion(false)
            return
        }
        
        isCaching = true
        
        let group = DispatchGroup()
        templates.forEach({ template in
            prepareContentsForTemplate(template, in: group) { (innerTemplate) in
                queue.async {
                    callback(innerTemplate)
                }
            }
        })
        
        group.notify(queue: queue) { [weak self] in
            self?.isCaching = false
            completion(true)
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
        } else if let template = item as? Template,
                  screenshot != nil
        {
            var displayString: String
            cachingLock.readLock()
            displayString =
                self.cachedPreviewContents[template.uuid.uuidString]?.content
                ?? self.cachedPreviewContents[template.uuid.uuidString]?.error
                ?? NSLocalizedString("Generating...", comment: "Outline Generation")
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
    
    func outlineView(_ outlineView: NSOutlineView, shouldExpandItem item: Any) -> Bool {
        guard let template = item as? Template else { return false }
        
        if isExpanding {
            return true
        }
        
        guard cachingLock.tryReadLock() else { return false }
        
        let itemCached = cachedPreviewContents
            .filter({ !$0.value.hasError })
            .keys
            .compactMap({ $0 })
            .contains(template.uuid.uuidString)
        cachingLock.unlock()
        
        if itemCached {
            return true
        }
        
        return !isProcessing
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldCollapseItem item: Any) -> Bool {
        guard let template = item as? Template else { return false }
        
        if isCollapsing {
            return true
        }
        
        guard cachingLock.tryReadLock() else { return false }
        
        let itemCached = cachedPreviewContents
            .filter({ !$0.value.hasError })
            .keys
            .compactMap({ $0 })
            .contains(template.uuid.uuidString)
        cachingLock.unlock()
        
        if itemCached {
            return true
        }
        
        return !isProcessing
    }
    
    func outlineViewItemDidExpand(_ notification: Notification) {
        guard notification.object as? NSObject == outlineView else { return }
        guard !isProcessing else { return }
        guard let expandedTemplates = notification.userInfo?.values.compactMap({ $0 as? Template }), expandedTemplates.count > 0 else { return }
        guard cachingLock.tryReadLock() else { return }
        
        let cachedKeys = cachedPreviewContents
            .filter({ !$0.value.hasError })
            .keys
            .compactMap({ $0 })
        cachingLock.unlock()
        
        let templatesToLoad = expandedTemplates.filter({ !cachedKeys.contains($0.uuid.uuidString) })
        guard templatesToLoad.count > 0 else { return }
        
        updateViewState()
        clearContentsForTemplates(templatesToLoad)
        reloadContentsForTemplates(templatesToLoad)
        
        isReloading = true
        prepareContentsForTemplates(expandedTemplates, in: .main) { [weak self] (template) in
            self?.outlineView.reloadItem(template, reloadChildren: true)
        } completionHandler: { [weak self] (finished) in
            self?.updateViewState()
            self?.isReloading = false
        }
    }

}

extension TemplatePreviewController {
    
    @objc private func templatesWillLoad(_ noti: Notification) {
        backupExpandedState()
        updateViewState()
    }
    
    @objc private func templatesDidLoad(_ noti: Notification) {
        processPreviewContext()
    }
    
}
