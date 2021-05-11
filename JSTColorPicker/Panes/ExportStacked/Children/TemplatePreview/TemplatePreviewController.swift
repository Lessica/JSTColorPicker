//
//  TemplatePreviewController.swift
//  JSTColorPicker
//
//  Created by Rachel on 4/15/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa
import PromiseKit
import SyntaxKit

private extension NSUserInterfaceItemIdentifier {
    static let columnName = NSUserInterfaceItemIdentifier("col-name")
}

private extension NSUserInterfaceItemIdentifier {
    static let cellTemplate         = NSUserInterfaceItemIdentifier("cell-template")
    static let cellTemplateContent  = NSUserInterfaceItemIdentifier("cell-template-content")
}

class TemplatePreviewController: StackedPaneController, EffectiveAppearanceObserver {

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
    @IBOutlet weak var outlineView            : TemplateOutlineView!
    @IBOutlet weak var emptyOutlineLabel      : NSTextField!
    @IBOutlet      var outlineMenu            : NSMenu!
    @IBOutlet      var outlineHeaderMenu      : NSMenu!
    @IBOutlet weak var togglePreviewMenuItem  : NSMenuItem!
    @IBOutlet weak var toggleAllMenuItem      : NSMenuItem!
    @IBOutlet weak var setAsSelectedMenuItem  : NSMenuItem!

    private        var documentContent        : Content?         { screenshot?.content }
    private        var documentExport         : ExportManager?   { screenshot?.export  }
    private        var documentState          : Screenshot.State { screenshot?.state ?? .notLoaded }

    private        let observableKeys         : [UserDefaults.Key] = [.maximumPreviewLineCount, .enableSyntaxHighlighting]
    private        var observables            : [Observable]?
    
    private        var syntaxHighlighting     : Bool = UserDefaults.standard[.enableSyntaxHighlighting]
    private        var maximumNumberOfLines   : Int = min(max(UserDefaults.standard[.maximumPreviewLineCount], 5), 99)

    private var actionSelectedRowIndex: Int? {
        (outlineView.clickedRow >= 0 && !outlineView.selectedRowIndexes.contains(outlineView.clickedRow)) ? outlineView.clickedRow : outlineView.selectedRowIndexes.first
    }

    @IBAction private func timerButtonTapped(_ sender: NSButton) {
        // TODO
    }

    private var documentContentObservarion: NSKeyValueObservation?

    override func load(_ screenshot: Screenshot) throws {
        saveExpandedState()
        try super.load(screenshot)
        entirelyProcessPreviewContext()
        
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

        documentContentObservarion = documentContent?.observe(
            \.items,
            options: [.new],
            changeHandler:
                { [weak self] in self?.documentContentChanged($0, $1) }
        )
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        outlineView.appearanceObserver = self
        prepareDefaults()
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
        reloadDataIfNeeded()
    }
    
    func viewDidChangeEffectiveAppearance() {
        setNeedsReloadData()
        guard !isPaneHidden && !isWindowHidden else {
            return
        }
        reloadDataIfNeeded()
    }
    
    @objc private func windowVisibilityDidChange(_ noti: Notification) {
        processPreviewContextIfNeeded()
        reloadDataIfNeeded()
    }
    
    deinit {
        if isReloading {
            isReloading = false
        }  // we must unlock shared manager
        NotificationCenter.default.removeObserver(self)
    }


    // MARK: - Defaults

    private func prepareDefaults() { }
    
    private func reloadOutlineView(
        forRowIndexes rows: IndexSet,
        forExpandedRowIndexes expandedRows: Bool,
        forAllRowIndexes allRows: Bool,
        byScrollingToTop scrollToTop: Bool,
        byNotingRowHeightsChanged heightsChanged: Bool,
        entirely: Bool
    ) {
        assert(Thread.isMainThread)
        if scrollToTop {
            outlineView.scrollToBeginningOfDocument(self)
        }
        if entirely {
            outlineView.reloadData()
        } else {
            var rowsToReload: IndexSet
            if allRows {
                rowsToReload = IndexSet(integersIn: 0..<outlineView.numberOfRows)
            } else if expandedRows {
                var rowSet = IndexSet()
                for rowIndex in IndexSet(integersIn: 0..<outlineView.numberOfRows) {
                    let rowItem = outlineView.item(atRow: rowIndex)
                    if outlineView.isItemExpanded(rowItem) {
                        let childrenCount = outlineView.numberOfChildren(ofItem: rowItem)
                        if childrenCount > 0 {
                            let rowRange = rowIndex...rowIndex + childrenCount
                            rowSet.insert(integersIn: rowRange)
                        }
                    }
                }
                rowsToReload = rowSet
            } else {
                rowsToReload = rows
            }
            outlineView.reloadData(
                forRowIndexes: rowsToReload,
                columnIndexes: IndexSet(integersIn: 0..<outlineView.numberOfColumns)
            )
            if heightsChanged {
                outlineView.noteHeightOfRows(
                    withIndexesChanged: rowsToReload
                )
            }
        }
    }

    private func applyDefaults(_ defaults: UserDefaults, _ defaultKey: UserDefaults.Key, _ defaultValue: Any) {
        if defaultKey == .maximumPreviewLineCount, let toValue = defaultValue as? Int {
            maximumNumberOfLines = toValue
            reloadOutlineView(
                forRowIndexes: IndexSet(),
                forExpandedRowIndexes: true,
                forAllRowIndexes: false,
                byScrollingToTop: false,
                byNotingRowHeightsChanged: true,
                entirely: false
            )
        }
        else if defaultKey == .enableSyntaxHighlighting, let toValue = defaultValue as? Bool {
            syntaxHighlighting = toValue
            reloadOutlineView(
                forRowIndexes: IndexSet(),
                forExpandedRowIndexes: true,
                forAllRowIndexes: false,
                byScrollingToTop: false,
                byNotingRowHeightsChanged: false,
                entirely: false
            )
        }
    }
    
    
    // MARK: - Syntax Highlighting
    
    private var _shouldReloadData: Bool = false
    private func setNeedsReloadData() {
        _shouldReloadData = true
    }
    private func reloadDataIfNeeded() {
        if _shouldReloadData {
            _shouldReloadData = false
            reloadOutlineView(
                forRowIndexes: IndexSet(),
                forExpandedRowIndexes: true,
                forAllRowIndexes: false,
                byScrollingToTop: false,
                byNotingRowHeightsChanged: false,
                entirely: false
            )
        }
    }
    
    private static let highlightMaximumLines              : Int = 128
    private static let highlightMaximumCharactersPerLine  : Int = 256
    private static func shouldHighlightContents(_ contents: String) -> Bool {
        guard !contents.isEmpty else { return false }
        
        // line count
        var beginIndex: String.Index = contents.startIndex
        let endIndex: String.Index = contents.endIndex
        var lineCount = 0
        while let separatorRange = contents.range(of: "\n", options: [], range: beginIndex..<endIndex)
        {
            beginIndex = separatorRange.upperBound
            lineCount += 1
            guard lineCount < highlightMaximumLines else { return false }
        }
        
        // character count
        guard contents.split(separator: "\n").firstIndex(where: { $0.count > highlightMaximumCharactersPerLine }) == nil
        else { return false }
        
        return true
    }
    
    private static let registeredLanguageIdentifiers      : [String] = [
        "source.json",
        "source.lua",
        "text.xml",
        "text.xml.plist",
        "source.yaml",
    ]
    
    private static var registeredLanguages                : [Language] = {
        return registeredLanguageIdentifiers.compactMap({ syntaxManager.language(withIdentifier: $0) })
    }()
    
    private static func languageForExtension(_ ext: String) -> Language? {
        return registeredLanguages.first(where: { $0.fileTypes.contains(ext) })
    }
    
    private static let syntaxBundle   = Bundle(url: Bundle.main.url(forResource: "TemplatePreview", withExtension: "bundle")!)!
    private static let syntaxManager  = BundleManager { (identifier, type) -> (URL?) in
        if identifier == "source.json" && type == .language {
            return syntaxBundle.url(forResource: "JSON", withExtension: "tmLanguage")
        }
        else if identifier == "source.lua" && type == .language {
            return syntaxBundle.url(forResource: "Lua", withExtension: "tmLanguage")
        }
        else if identifier == "source.yaml" && type == .language {
            return syntaxBundle.url(forResource: "YAML", withExtension: "tmLanguage")
        }
        else if identifier == "text.xml" && type == .language {
            return syntaxBundle.url(forResource: "XML", withExtension: "tmLanguage")
        }
        else if identifier == "text.xml.plist" && type == .language {
            return syntaxBundle.url(forResource: "Property List (XML)", withExtension: "tmLanguage")
        }
        else if identifier == "theme.light.tomorrow" && type == .theme {
            return syntaxBundle.url(forResource: "Tomorrow", withExtension: "tmTheme")
        }
        else if identifier == "theme.dark.tomorrow" && type == .theme {
            return syntaxBundle.url(forResource: "Tomorrow-Night", withExtension: "tmTheme")
        }
        return nil
    }
    
    private static func syntaxFontCallback(_ fontName: String, _ fontSize: CGFloat, _ fontStyle: FontStyle) -> (Font?) {
        switch fontStyle {
        case .bold:
            return Font.monospacedSystemFont(ofSize: TemplateContentCellView.defaultFontSize, weight: .bold)
        case .italic:
            return Font.monospacedSystemFont(ofSize: TemplateContentCellView.defaultFontSize, weight: .regular).italic()
        case .boldItalic:
            return Font.monospacedSystemFont(ofSize: TemplateContentCellView.defaultFontSize, weight: .bold).italic()
        default:
            return Font.monospacedSystemFont(ofSize: TemplateContentCellView.defaultFontSize, weight: .regular)
        }
    }
    
    private static var lightTheme: Theme = {
        return TemplatePreviewController.syntaxManager.theme(
            withIdentifier: "theme.light.tomorrow",
            fontCallback: TemplatePreviewController.syntaxFontCallback(_:_:_:)
        )!
    }()
    
    private static var darkTheme: Theme = {
        return TemplatePreviewController.syntaxManager.theme(
            withIdentifier: "theme.dark.tomorrow",
            fontCallback: TemplatePreviewController.syntaxFontCallback(_:_:_:)
        )!
    }()
    
    private var effectiveTheme: Theme {
        return view.effectiveAppearance.isLight ? TemplatePreviewController.lightTheme : TemplatePreviewController.darkTheme
    }
    
    private func effectiveParserForExtension(_ ext: String) -> AttributedParser? {
        guard let language = TemplatePreviewController.languageForExtension(ext) else { return nil }
        return AttributedParser(language: language, theme: effectiveTheme)
    }
    
    private func effectiveParserForTemplate(_ tmpl: Template) -> AttributedParser? {
        guard let ext = tmpl.userExtension else { return nil }
        return effectiveParserForExtension(ext)
    }
    
    
    // MARK: - Context

    private static let sharedContextQueue               : DispatchQueue = DispatchQueue(label: "TemplateSharedContext.Queue", qos: .userInitiated)
    private var _shouldProcessContext                   : Bool = false {
        willSet {
            assert(Thread.isMainThread)
        }
    }
    
    private func setNeedsProcessContext() {
        _shouldProcessContext = true
    }
    
    @objc private func processPreviewContextIfNeeded() {
        if _shouldProcessContext {
            _shouldProcessContext = false
            entirelyProcessPreviewContext()
        }
    }

    private func documentContentChanged(_ content: Content, _ change: NSKeyValueObservedChange<[ContentItem]>) {
        saveExpandedState()
        entirelyProcessPreviewContext()
    }
    
    private func entirelyProcessPreviewContext() {
        assert(Thread.isMainThread)
        guard !isPaneHidden && !isWindowHidden && !isProcessing else {
            NSObject.cancelPreviousPerformRequests(
                withTarget: self,
                selector: #selector(processPreviewContextIfNeeded),
                object: nil
            )
            setNeedsProcessContext()
            return
        }
        
        self.updateViewState()
        self.clearContentsForAsyncTemplates()
        
        let templatesToReload = previewableTemplates
            .filter({ cachedExpandedState?.contains($0.uuid.uuidString) ?? false })
        let isKeyOrMain = (view.window?.isKeyWindow ?? false) || (view.window?.isMainWindow ?? false)
        
        self.isExpanding = true
        self.reloadOutlineView(
            forRowIndexes: IndexSet(),
            forExpandedRowIndexes: false,
            forAllRowIndexes: true,
            byScrollingToTop: true,
            byNotingRowHeightsChanged: true,
            entirely: true
        )
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.restoreExpandedState()
            self.isExpanding = false
        }
        
        self.isReloading = true
        self.updateViewState()
        TemplatePreviewController.sharedContextQueue.asyncAfter(
            deadline: .now() + (isKeyOrMain ? 0.1 : 0.3),
            qos: isKeyOrMain ? .utility : .background,
            flags: [.enforceQoS]
        ) { [weak self] in
            guard let self = self else { return }
            let sema = DispatchSemaphore(value: 0)
            self.prepareContentsForTemplates(templatesToReload)
            { [weak self] (template) in
                guard let self = self else { return }
                self.outlineView.reloadItem(template, reloadChildren: true)
            } completionHandler: { [weak self] (finished) in
                guard let self = self else { return }
                self.isReloading = false
                self.updateViewState()
                sema.signal()
                
                self.perform(
                    #selector(self.processPreviewContextIfNeeded),
                    with: nil,
                    afterDelay: 0.5
                )
            }
            sema.wait()
        }
    }
    
    private func partialProcessPreviewContextForTemplates(_ templates: [Template], force: Bool) {
        assert(Thread.isMainThread)
        var templatesToLoad: [Template]
        if !force {
            guard !isProcessing,
                  cachingLock.tryReadLock()
            else {
                return
            }
            
            let cachedKeys = cachedPreviewContents
                .filter({ $0.value.hasContents })
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
        
        self.isReloading = true
        self.updateViewState()
        self.outlineView.beginUpdates()
        self.reloadContentsForTemplates(templatesToLoad)
        self.prepareContentsForTemplates(templatesToLoad) { [weak self] (template) in
            guard let self = self else { return }
            self.outlineView.reloadItem(template, reloadChildren: true)
        } completionHandler: { [weak self] (finished) in
            guard let self = self else { return }
            self.outlineView.endUpdates()
            self.isReloading = false
            self.updateViewState()
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
        assert(Thread.isMainThread)
        templates.forEach({ outlineView.reloadItem($0, reloadChildren: true) })
    }

    private func reloadContentsForTemplate(_ template: Template) {
        assert(Thread.isMainThread)
        outlineView.reloadItem(template, reloadChildren: true)
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
        assert(Thread.isMainThread)
        return previewableTemplates
            .filter({ outlineView.isItemExpanded($0) })
            .map({ $0.uuid.uuidString })
    }
    
    private func saveExpandedState() {
        assert(Thread.isMainThread)
        if cachedExpandedState == nil {
            cachedExpandedState = currentExpandedState
        }
    }
    
    private func restoreExpandedState() {
        assert(Thread.isMainThread)
        isExpanding = true
        cachedExpandedState?
            .compactMap({ templateWithUUIDString($0) })
            .filter({ outlineView.isExpandable($0) && !outlineView.isItemExpanded($0) })
            .forEach({ outlineView.expandItem($0) })
        cachedExpandedState = nil
        isExpanding = false
    }
    
    private func clearExpandedState() {
        assert(Thread.isMainThread)
        cachedExpandedState = nil
    }
    
    
    // MARK: - Prepare Contents
    
    private var cachedPreviewContents  : [String: TemplatePreviewObject] = [:]
    private let cachingQueue           : DispatchQueue = DispatchQueue(label: "CachedPreviewContents.Queue", qos: .userInitiated, attributes: .concurrent)
    private let cachingLock            : ReadWriteLock = ReadWriteLock()
    
    private func clearContentsForTemplate(_ template: Template) {
        cachingLock.writeLock()
        if let previewObj = cachedPreviewContents[template.uuid.uuidString] {
            previewObj.clear()
        }
        cachingLock.unlock()
    }
    
    private func clearContentsForTemplates(_ templates: [Template]) {
        cachingLock.writeLock()
        templates.forEach(
            {
                if let previewObj = cachedPreviewContents[$0.uuid.uuidString] {
                    previewObj.clear()
                }
            }
        )
        cachingLock.unlock()
    }
    
    private func clearContentsForAllTemplates() {
        cachingLock.writeLock()
        cachedPreviewContents.forEach({ $0.value.clear() })
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
            
            self.cachingLock.writeLock()
            if let previewObj = self.cachedPreviewContents[template.uuid.uuidString] {
                previewObj.clear()
                do {
                    previewObj.contents = (try exportManager.generateAllContentItems(with: template, forPreviewOnly: true))
                        .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                } catch {
                    previewObj.error = error.localizedDescription
                }
            } else {
                var previewObj: TemplatePreviewObject
                do {
                    previewObj = TemplatePreviewObject(
                        uuidString: template.uuid.uuidString,
                        contents: (try exportManager.generateAllContentItems(with: template, forPreviewOnly: true))
                            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
                        error: nil
                    )
                } catch {
                    previewObj = TemplatePreviewObject(
                        uuidString: template.uuid.uuidString,
                        contents: nil,
                        error: error.localizedDescription
                    )
                }
                self.cachedPreviewContents[template.uuid.uuidString] = previewObj
            }
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
        else if menuItem.action == #selector(toggleAll(_:)) {
            return outlineView.numberOfRows > 0
        }
        else if menuItem.action == #selector(resetColumns(_:)) {
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
    
    @IBAction private func togglePreview(_ sender: Any?) {
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
    
    @IBAction private func toggleAll(_ sender: Any?) {
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

    @IBAction private func copy(_ sender: Any?) {
        var succeed = true
        when(
            fulfilled: promiseCheckAllContentItems(), promiseCheckSelectedTemplate()
        ).then {
            self.promiseExtractContentItems($0.0, template: $0.1)
        }.then {
            self.promiseFetchContentItems($0.0, template: $0.1)
        }.then {
            self.promiseWriteCachedContents($0.0, template: $0.1)
        }.then {
            self.promiseCopyContentsToGeneralPasteboard($0.0)
        }.catch {
            self.presentError($0)
            succeed = false
        }.finally {
            let shouldMakeSound: Bool = UserDefaults.standard[.makeSoundsAfterDoubleClickCopy]
            if succeed && shouldMakeSound {
                NSSound(named: "Copy")?.play()
            }
        }
    }

    @IBAction private func exportAs(_ sender:  Any?) {
        var succeed = true
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
            succeed = false
        }.finally {
            let shouldMakeSound: Bool = UserDefaults.standard[.makeSoundsAfterDoubleClickCopy]
            if succeed && shouldMakeSound {
                let locate: Bool = UserDefaults.standard[.locateExportedItemsAfterOperation]
                if locate, let url = targetURL {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                NSSound(named: "Paste")?.play()
            }
        }
    }

    @IBAction private func regenerate(_ sender: NSMenuItem) {
        guard let template = try? promiseCheckSelectedTemplate().wait() else { return }
        partialProcessPreviewContextForTemplates([template], force: true)
    }

    @IBAction private func setAsSelected(_ sender: NSMenuItem) {
        guard let template = try? promiseCheckSelectedTemplate().wait() else { return }
        TemplateManager.shared.selectedTemplate = template
    }

    @IBAction private func outlineViewAction(_ sender: TemplateOutlineView) {
        // do nothing
    }

    @IBAction private func outlineViewDoubleAction(_ sender: TemplateOutlineView) {
        guard let event = NSApp.currentEvent else { return }
        let locationInView = sender.convert(event.locationInWindow, from: nil)
        guard sender.bounds.contains(locationInView) else { return }
        copy(sender)
    }

    @IBAction private func resetColumns(_ sender: NSMenuItem) {
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
                guard !selectedObject.isPlaceholder else {
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
                seal.fulfill((try exportManager.generateContentItems(items, with: template, forPreviewOnly: false), template))
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

            if let previewObj = cachedPreviewContents[template.uuid.uuidString] {
                previewObj.contents = contents
                previewObj.error = nil
            } else {
                cachedPreviewContents[template.uuid.uuidString] = TemplatePreviewObject(
                    uuidString: template.uuid.uuidString,
                    contents: contents,
                    error: nil
                )
            }

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
            let exportOptionView = ExportPanelAccessoryView.instantiateFromNib(withOwner: self)
            panel.accessoryView = exportOptionView
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
            obj = self.cachedPreviewContents[template.uuid.uuidString] ?? .placeholder
            cachingLock.unlock()
            return obj
        }
        return TemplatePreviewObject.placeholder
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
    
    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        var rowView = outlineView.makeView(withIdentifier: TemplateRowView.itemIdentifier, owner: self)
        if rowView == nil {
            rowView = TemplateRowView()
            rowView?.identifier = TemplateRowView.itemIdentifier
        }
        return rowView as? NSTableRowView
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
                var attributedText: NSAttributedString
                if !documentState.isLoaded {
                    attributedText = NSAttributedString(
                        string: Error.documentNotLoaded.localizedDescription,
                        attributes: TemplateContentCellView.defaultTextAttributes
                    )
                } else if let contents = templateObj.contents,
                          let template = templateWithUUIDString(templateObj.uuidString)
                {
                    if syntaxHighlighting,
                       TemplatePreviewController.shouldHighlightContents(contents),
                       let parser = effectiveParserForTemplate(template)
                    {
                        attributedText = parser.attributedString(
                            for: contents,
                            base: TemplateContentCellView.defaultTextAttributes
                        )
                    } else {
                        attributedText = NSAttributedString(
                            string: contents,
                            attributes: TemplateContentCellView.defaultTextAttributes
                        )
                    }
                } else if let errorString = templateObj.error {
                    attributedText = NSAttributedString(
                        string: errorString,
                        attributes: TemplateContentCellView.defaultTextAttributes
                    )
                } else {
                    attributedText = NSAttributedString(
                        string: NSLocalizedString("Generating…", comment: "Outline Generation"),
                        attributes: TemplateContentCellView.defaultTextAttributes
                    )
                }
                
                cell.attributedText = attributedText
                cell.maximumNumberOfLines = maximumNumberOfLines
                return cell
            }
        }
        return nil
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        if item is TemplatePreviewObject {
            return true
        }
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldExpandItem item: Any) -> Bool {
        guard let template = item as? Template else { return false }
        
        if isExpanding {
            return true
        }
        
        guard cachingLock.tryReadLock() else { return false }
        
        let itemCached = cachedPreviewContents
            .filter({ $0.value.hasContents })
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
            .filter({ $0.value.hasContents })
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
        entirelyProcessPreviewContext()
    }
    
}
