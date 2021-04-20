//
//  TemplatePreviewController.swift
//  JSTColorPicker
//
//  Created by Rachel on 4/15/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa
import PromiseKit

private extension NSUserInterfaceItemIdentifier {
    static let columnName = NSUserInterfaceItemIdentifier("col-name")
}

private extension NSUserInterfaceItemIdentifier {
    static let cellTemplate         = NSUserInterfaceItemIdentifier("cell-template")
    static let cellTemplateContent  = NSUserInterfaceItemIdentifier("cell-template-content")
}

struct TemplatePreviewObject: Equatable {
    let uuidString: String
    let contents: String?
    let error: String?
    var hasError: Bool { error != nil }
    static let empty = TemplatePreviewObject(uuidString: "", contents: nil, error: nil)
}

class TemplatePreviewController: StackedPaneController {

    enum Error: LocalizedError {
        case documentNotLoaded
        case noTemplateSelected
        case cannotWriteToPasteboard
        case resourceNotFound
        case resourceBusy

        var failureReason: String? {
            switch self {
            case .documentNotLoaded:
                return NSLocalizedString("Document not loaded.", comment: "TemplatePreviewController.Error")
            case .noTemplateSelected:
                return NSLocalizedString("No template selected.", comment: "TemplatePreviewController.Error")
            case .cannotWriteToPasteboard:
                return NSLocalizedString("Ownership of the pasteboard has changed.", comment: "TemplatePreviewController.Error")
            case .resourceNotFound:
                return NSLocalizedString("Resource not found.", comment: "TemplatePreviewController.Error")
            case .resourceBusy:
                return NSLocalizedString("Resource busy.", comment: "TemplatePreviewController.Error")
            }
        }
    }

    override var menuIdentifier: NSUserInterfaceItemIdentifier { NSUserInterfaceItemIdentifier("show-template-preview") }

    @IBOutlet weak var timerButton            : NSButton!
    @IBOutlet weak var outlineView            : NSOutlineView!
    @IBOutlet weak var emptyOutlineLabel      : NSTextField!
    @IBOutlet      var outlineMenu            : NSMenu!
    @IBOutlet      var outlineHeaderMenu      : NSMenu!
    @IBOutlet weak var togglePreviewMenuItem  : NSMenuItem!
    @IBOutlet weak var toggleAllMenuItem      : NSMenuItem!

    private        var documentContent        : Content?         { screenshot?.content }
    private        var documentExport         : ExportManager?   { screenshot?.export  }
    private        var documentState          : Screenshot.State { screenshot?.state ?? .notLoaded }

    private        let observableKeys         : [UserDefaults.Key] = [.maximumPreviewLineCount]
    private        var observables            : [Observable]?
    private        var maximumNumberOfLines   : Int = min(max(UserDefaults.standard[.maximumPreviewLineCount], 5), 99)

    private var actionSelectedRowIndex: Int? {
        (outlineView.clickedRow >= 0 && !outlineView.selectedRowIndexes.contains(outlineView.clickedRow)) ? outlineView.clickedRow : outlineView.selectedRowIndexes.first
    }

    @IBAction func timerButtonTapped(_ sender: NSButton) {
        // TODO
    }

    private var documentContentObservarion: NSKeyValueObservation?

    override func load(_ screenshot: Screenshot) throws {
        saveExpandedState()
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

        documentContentObservarion = documentContent?
            .observe(
                \.items,
                options: [.new],
                changeHandler:
                    { [weak self] in self?.documentContentChanged($0, $1) }
            )
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateViewState()

        observables = UserDefaults.standard.observe(keys: observableKeys, callback: { [weak self] in self?.applyDefaults($0, $1, $2) })
        
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


    // MARK: - Defaults

    private func prepareDefaults() { }

    private func applyDefaults(_ defaults: UserDefaults, _ defaultKey: UserDefaults.Key, _ defaultValue: Any) {
        if defaultKey == .maximumPreviewLineCount, let toValue = defaultValue as? Int {
            maximumNumberOfLines = toValue
            outlineView.reloadData()
        }
    }
    
    
    // MARK: - Context

    private static let sharedContextQueue  : DispatchQueue = DispatchQueue(label: "TemplateSharedContext.Queue", qos: .background)
    private var _shouldProcessContext      : Bool = false
    
    private func setNeedsProcessContext() {
        _shouldProcessContext = true
    }
    
    private func processPreviewContextIfNeeded() {
        if _shouldProcessContext {
            _shouldProcessContext = false
            processPreviewContext()
        }
    }

    private func documentContentChanged(_ content: Content, _ change: NSKeyValueObservedChange<[ContentItem]>) {
        saveExpandedState()
        processPreviewContext()
    }
    
    private func processPreviewContext() {
        guard !isPaneHidden && !isWindowHidden else {
            _shouldProcessContext = true
            return
        }
        guard !isProcessing else { return }
        
        self.updateViewState()
        self.clearContentsForAsyncTemplates()
        
        self.isExpanding = true
        self.outlineView.reloadData()
        let templatesToReload = previewableTemplates
            .filter({ cachedExpandedState?.contains($0.uuid.uuidString) ?? false })
        DispatchQueue.main.async { [weak self] in
            self?.restoreExpandedState()
            //isExpanding = false
        }

        let isKeyOrMain = (view.window?.isKeyWindow ?? false) || (view.window?.isMainWindow ?? false)

        self.isReloading = true
        self.updateViewState()
        TemplatePreviewController.sharedContextQueue.asyncAfter(
            deadline: .now() + (isKeyOrMain ? 0.1 : 0.5),
            qos: isKeyOrMain ? .utility : .background,
            flags: [.enforceQoS]
        ) { [weak self] in
            let sema = DispatchSemaphore(value: 0)
            self?.prepareContentsForTemplates(templatesToReload)
            { [weak self] (template) in
                self?.outlineView.reloadItem(template, reloadChildren: true)
            } completionHandler: { [weak self] (finished) in
                self?.isReloading = false
                self?.updateViewState()
                sema.signal()
            }
            sema.wait()
        }
    }
    
    private func partialProcessPreviewContextForTemplates(_ templates: [Template], force: Bool) {
        var templatesToLoad: [Template]
        if !force {
            guard !isProcessing,
                  cachingLock.tryReadLock()
            else {
                return
            }
            
            let cachedKeys = cachedPreviewContents
                .filter({ !$0.value.hasError })
                .keys
                .compactMap({ $0 })
            cachingLock.unlock()
            
            templatesToLoad = templates.filter({ !cachedKeys.contains($0.uuid.uuidString) })
            guard templatesToLoad.count > 0 else {
                return
            }
        } else {
            guard !isProcessing else { return }
            templatesToLoad = templates
        }
        
        self.clearContentsForTemplates(templatesToLoad)
        self.reloadContentsForTemplates(templatesToLoad)
        
        self.isReloading = true
        self.updateViewState()
        self.prepareContentsForTemplates(templatesToLoad) { [weak self] (template) in
            self?.outlineView.reloadItem(template, reloadChildren: true)
        } completionHandler: { [weak self] (finished) in
            self?.isReloading = false
            self?.updateViewState()
        }
    }


    // MARK: - Templates
    
    private var isProcessing           : Bool { isReloading || isExpanding || isCollapsing }
    private var previewableTemplates   : [Template] { TemplateManager.shared.previewableTemplates }

    private func templateWithUUIDString(_ uuidString: String) -> Template? {
        let template = TemplateManager.shared.templateWithUUIDString(uuidString)
        guard template?.isPreviewable ?? false else { return nil }
        return template
    }
    
    
    // MARK: - View States

    private var isReloading            : Bool = false {
        willSet {
            assert(Thread.isMainThread)
        }
        didSet {
            if isReloading {
                TemplateManager.shared.lock()
            } else {
                TemplateManager.shared.unlock()
            }
        }
    }
    
    private func updateViewState() {
        assert(Thread.isMainThread)
        if previewableTemplates.isEmpty {
            outlineView.isEnabled = false
            emptyOutlineLabel.isHidden = false
        } else {
            outlineView.isEnabled = !isReloading
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
    private var isExpanding            : Bool = false {
        willSet {
            assert(Thread.isMainThread)
        }
    }
    private var isCollapsing           : Bool = false {
        willSet {
            assert(Thread.isMainThread)
        }
    }
    
    private var currentExpandedState   : [String]
    {
        return previewableTemplates
            .filter({ outlineView.isItemExpanded($0) })
            .map({ $0.uuid.uuidString })
    }
    
    private func saveExpandedState() {
        if cachedExpandedState == nil {
            cachedExpandedState = currentExpandedState
        }
    }
    
    private func restoreExpandedState() {
        isExpanding = true
        cachedExpandedState?
            .compactMap({ templateWithUUIDString($0) })
            .filter({ outlineView.isExpandable($0) && !outlineView.isItemExpanded($0) })
            .forEach({ outlineView.expandItem($0) })
        cachedExpandedState = nil
        isExpanding = false
    }
    
    
    // MARK: - Preview Contents
    
    private var cachedPreviewContents  : [String: TemplatePreviewObject] = [:]
    private let cachingQueue           : DispatchQueue = DispatchQueue(label: "CachedPreviewContents.Queue", qos: .background, attributes: .concurrent)
    private let cachingLock            : ReadWriteLock = ReadWriteLock()
    
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

    private func clearContentsForAsyncTemplates() {
        cachingLock.writeLock()
        cachedPreviewContents = cachedPreviewContents.filter({ !(templateWithUUIDString($0.key)?.isAsync ?? false) })
        cachingLock.unlock()
    }
    
    private func clearContentsWithError() {
        cachingLock.writeLock()
        cachedPreviewContents = cachedPreviewContents.filter({ !$0.value.hasError })
        cachingLock.unlock()
    }
    
    private func prepareContentsForTemplate(_ template: Template, group: DispatchGroup, completionHandler completion: @escaping (Template) -> Void) {
        guard let exportManager = documentExport else { return }
        group.enter()
        cachingQueue.async { [weak self] in
            guard let self = self else {
                group.leave()
                return
            }
            
            var previewObj: TemplatePreviewObject
            do {
                previewObj = TemplatePreviewObject(
                    uuidString: template.uuid.uuidString,
                    contents: try exportManager.generateAllContentItems(with: template),
                    error: nil
                )
            } catch {
                previewObj = TemplatePreviewObject(
                    uuidString: template.uuid.uuidString,
                    contents: nil,
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
        prepareContentsForTemplates(previewableTemplates, queue: queue, callback: callback, completionHandler: completion)
    }

    private func prepareContentsForTemplates(
        _ templates: [Template],
        queue: DispatchQueue = .main,
        callback: @escaping (Template) -> Void,
        completionHandler completion: @escaping (Bool) -> Void
    ) {
        let group = DispatchGroup()
        templates.forEach({ template in
            prepareContentsForTemplate(template, group: group) { (innerTemplate) in
                queue.async {
                    callback(innerTemplate)
                }
            }
        })
        
        group.notify(queue: queue) {
            completion(true)
        }
    }

}

// MARK: - Promised Actions
extension TemplatePreviewController: NSMenuItemValidation, NSMenuDelegate {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard !isProcessing else {
            return false
        }
        if menuItem.action == #selector(togglePreview(_:))
            || menuItem.action == #selector(setAsSelected(_:))
        {
            guard let template = try? promiseCheckSelectedTemplate().wait()
            else { return false }
            
            if menuItem.action == #selector(setAsSelected(_:)) {
                guard template.uuid != TemplateManager.shared.selectedTemplateUUID
                else { return false }
            }
            
            return true
        }
        else if menuItem.action == #selector(regenerate(_:)) || menuItem.action == #selector(copy(_:)) || menuItem.action == #selector(exportAs(_:)) {
            return hasActionAvailability(
                promiseCheckSelectedTemplate(),
                promiseCheckAllContentItems()
            )
        }
        else if menuItem.action == #selector(toggleAll(_:)) || menuItem.action == #selector(resetColumns(_:)) {
            return true
        }
        return false
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu == outlineMenu {
            if let template = try? promiseCheckSelectedTemplate().wait() {
                togglePreviewMenuItem.title = outlineView.isItemExpanded(template)
                    ? NSLocalizedString("Collapse Preview", comment: "menuNeedsUpdate(_:)")
                    : NSLocalizedString("Expand Preview", comment: "menuNeedsUpdate(_:)")
            } else {
                togglePreviewMenuItem.title = NSLocalizedString("Expand/Collapse Preview", comment: "menuNeedsUpdate(_:)")
            }
            
            toggleAllMenuItem.title = !hasCollapsedItem
                ? NSLocalizedString("Collapse All Previews", comment: "menuNeedsUpdate(_:)")
                : NSLocalizedString("Expand All Previews", comment: "menuNeedsUpdate(_:)")
        }
    }
    
    @IBAction func togglePreview(_ sender: Any?) {
        guard let template = try? promiseCheckSelectedTemplate().wait() else { return }
        
        if !outlineView.isItemExpanded(template) && outlineView.isExpandable(template) {
            isExpanding = true
            outlineView.expandItem(template)
            isExpanding = false
            
            partialProcessPreviewContextForTemplates([template], force: false)
        } else {
            isCollapsing = true
            outlineView.collapseItem(template)
            isCollapsing = false
        }
    }
    
    var hasCollapsedItem: Bool { previewableTemplates.firstIndex(where: { !outlineView.isItemExpanded($0) }) != nil }
    
    @IBAction func toggleAll(_ sender: Any?) {
        if hasCollapsedItem {
            isExpanding = true
            outlineView.expandItem(nil, expandChildren: true)
            isExpanding = false
            
            partialProcessPreviewContextForTemplates(previewableTemplates, force: false)
        } else {
            isCollapsing = true
            outlineView.collapseItem(nil, collapseChildren: true)
            isCollapsing = false
        }
    }

    @IBAction func copy(_ sender: Any?) {
        when(
            fulfilled: promiseCheckAllContentItems(), promiseCheckSelectedTemplate()
        ).then {
            self.promiseExtractContentItems($0.0, template: $0.1)
        }.then {
            self.promiseFetchContentItems($0.0, template: $0.1)
        }.then {
            self.promiseWriteCachedContents($0.0, template: $0.1)
        }.then {
            self.promiseCopyContentsToGeneralPasteboard($0.0).asVoid()
        }.catch {
            self.presentError($0)
        }.finally {
            debugPrint("done copy(_:)")
        }
    }

    @IBAction func exportAs(_ sender:  Any?) {
        var targetURL: URL?
        when(
            fulfilled: promiseCheckAllContentItems(), promiseCheckSelectedTemplate()
        ).then {
            self.promiseTargetURLForContentItems($0.0, template: $0.1)
        }.then { (items, tmpl, url) -> Promise<([ContentItem], Template)> in
            targetURL = url
            return self.promiseExtractContentItems(items, template: tmpl)
        }.then {
            self.promiseFetchContentItems($0.0, template: $0.1)
        }.then {
            self.promiseWriteCachedContents($0.0, template: $0.1)
        }.then {
            self.promiseWriteContentsToURL(contents: $0.0, url: targetURL!).asVoid()
        }.catch {
            self.presentError($0)
        }.finally {
            debugPrint("done exportAs(_:)")
        }
    }

    @IBAction func regenerate(_ sender: NSMenuItem) {
        guard let template = try? promiseCheckSelectedTemplate().wait() else { return }
        partialProcessPreviewContextForTemplates([template], force: true)
    }

    @IBAction func setAsSelected(_ sender: NSMenuItem) {
        guard let template = try? promiseCheckSelectedTemplate().wait() else { return }
        TemplateManager.shared.selectedTemplate = template
    }

    @IBAction func outlineViewAction(_ sender: TemplateOutlineView) {
        // do nothing
    }

    @IBAction func outlineViewDoubleAction(_ sender: TemplateOutlineView) {
        guard let event = NSApp.currentEvent else { return }
        let locationInView = sender.convert(event.locationInWindow, from: nil)
        guard sender.bounds.contains(locationInView) else { return }
        copy(sender)
    }

    @IBAction func resetColumns(_ sender: NSMenuItem) {
        outlineView.tableColumns.forEach({ $0.width = 320 })
    }

    private func hasActionAvailability<U: Thenable>(_ condition: U) -> Bool {
        do {
            try condition.asVoid().wait()
            return true
        } catch {
            return false
        }
    }

    private func hasActionAvailability<U: Thenable, V: Thenable>(_ conditionU: U, _ conditionV: V) -> Bool {
        do {
            try conditionU.asVoid().wait()
            try conditionV.asVoid().wait()
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Promises
extension TemplatePreviewController {

    private func promiseCheckSelectedTemplate() -> Promise<Template>
    {
        Promise { seal in
            guard let selectedIndex = actionSelectedRowIndex,
                  let selectedItem = outlineView.item(atRow: selectedIndex)
            else {
                seal.reject(Error.noTemplateSelected)
                return
            }

            var selectedTemplate: Template?
            if selectedItem is Template {
                selectedTemplate = selectedItem as? Template
            } else if let selectedObject = selectedItem as? TemplatePreviewObject {
                guard selectedObject != .empty else {
                    seal.reject(Error.resourceNotFound)
                    return
                }
                selectedTemplate = templateWithUUIDString(selectedObject.uuidString)
            }

            guard let template = selectedTemplate else {
                seal.reject(Error.noTemplateSelected)
                return
            }

            seal.fulfill(template)
        }
    }

    private func promiseCheckAllContentItems() -> Promise<[ContentItem]>
    {
        Promise { seal in
            guard let content = screenshot?.content
            else {
                seal.reject(Error.documentNotLoaded)
                return
            }

            seal.fulfill(content.items)
        }
    }

    private func promiseExtractContentItems(_ items: [ContentItem], template: Template) -> Promise<([ContentItem], Template)>
    {
        Promise { seal in
            if template.isAsync {
                guard let screenshot = screenshot
                else {
                    seal.reject(Error.documentNotLoaded)
                    return
                }

                screenshot.extractContentItems(
                    in: view.window!,
                    with: template
                ) { (tmpl) in
                    seal.fulfill((items, tmpl))
                }
            } else {
                seal.fulfill((items, template))
            }
        }
    }

    private func promiseFetchContentItems(_ items: [ContentItem], template: Template) -> Promise<(String, Template)>
    {
        Promise { seal in
            guard let exportManager = documentExport else {
                seal.reject(Error.documentNotLoaded)
                return
            }

            do {
                seal.fulfill((try exportManager.generateContentItems(items, with: template), template))
            } catch {
                seal.reject(error)
            }
        }
    }

    private func promiseWriteCachedContents(_ contents: String, template: Template) -> Promise<(String, Template)>
    {
        Promise { seal in
            guard cachingLock.tryWriteLock() else {
                seal.reject(Error.resourceBusy)
                return
            }

            cachedPreviewContents[template.uuid.uuidString] = TemplatePreviewObject(
                uuidString: template.uuid.uuidString,
                contents: contents,
                error: nil
            )

            cachingLock.unlock()
            seal.fulfill((contents, template))
        }
    }

    private func promiseCopyContentsToGeneralPasteboard(_ contents: String) -> Promise<Bool>
    {
        Promise { seal in
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.string], owner: nil)

            guard pasteboard.setString(contents, forType: .string) else {
                seal.reject(Error.cannotWriteToPasteboard)
                return
            }

            seal.fulfill(true)
        }
    }

    private func promiseTargetURLForContentItems(_ items: [ContentItem], template: Template) -> Promise<([ContentItem], Template, URL)>
    {
        Promise { seal in
            guard let screenshot = screenshot
            else {
                seal.reject(Error.documentNotLoaded)
                return
            }

            let panel = NSSavePanel()
            panel.nameFieldStringValue = String(format: NSLocalizedString("%@ Exported %ld Items", comment: "exportAll(_:)"), screenshot.displayName ?? "", items.count)
            panel.allowedFileTypes = template.allowedExtensions
            panel.beginSheetModal(for: view.window!) { resp in
                if resp == .OK {
                    if let url = panel.url {
                        seal.fulfill((items, template, url))
                        return
                    }
                }

                seal.reject(PMKError.cancelled)
            }
        }
    }

    private func promiseWriteContentsToURL(contents: String, url: URL) -> Promise<Bool>
    {
        Promise { seal in
            if let data = contents.data(using: .utf8) {
                do {
                    try data.write(to: url)
                    seal.fulfill(true)
                } catch {
                    seal.reject(error)
                }
            } else {
                seal.fulfill(false)
            }
        }
    }
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
            var obj: TemplatePreviewObject
            cachingLock.readLock()
            obj = self.cachedPreviewContents[template.uuid.uuidString] ?? .empty
            cachingLock.unlock()
            return obj
        }
        return TemplatePreviewObject.empty
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
            if let template = item as? Template,
               let cell = outlineView.makeView(withIdentifier: .cellTemplate, owner: nil) as? TemplateCellView
            {
                cell.text = template.name
                return cell
            }
            else if let templateObj = item as? TemplatePreviewObject,
                    let cell = outlineView.makeView(withIdentifier: .cellTemplateContent, owner: nil) as? TemplateContentCellView
            {
                cell.text = documentState.isLoaded
                    ? (templateObj.contents ?? templateObj.error ?? NSLocalizedString("Generating...", comment: "Outline Generation"))
                    : Error.documentNotLoaded.localizedDescription
                cell.maximumNumberOfLines = maximumNumberOfLines
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

    func outlineViewItemWillExpand(_ notification: Notification) {
        guard notification.object as? NSObject == outlineView,
              !isProcessing
        else { return }
    }
    
    func outlineViewItemDidExpand(_ notification: Notification) {
        guard notification.object as? NSObject == outlineView,
              let expandedTemplates = notification.userInfo?.values.compactMap({ $0 as? Template }),
              expandedTemplates.count > 0
        else {
            return
        }
        
        partialProcessPreviewContextForTemplates(expandedTemplates, force: false)
    }

}

extension TemplatePreviewController {
    
    @objc private func templatesWillLoad(_ noti: Notification) {
        guard !isProcessing else { return }
        saveExpandedState()
        updateViewState()
    }
    
    @objc private func templatesDidLoad(_ noti: Notification) {
        processPreviewContext()
    }
    
}
