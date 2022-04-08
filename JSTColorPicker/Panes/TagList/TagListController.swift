//
//  TagListController.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/5/24.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

private extension NSUserInterfaceItemIdentifier {
    static let columnFlags      = NSUserInterfaceItemIdentifier("col-flags")
    static let columnChecked    = NSUserInterfaceItemIdentifier("col-checked")
    static let columnName       = NSUserInterfaceItemIdentifier("col-name")
}

@objc private class TagListControllerWrapper: NSObject {
    weak var object: TagListController?
    init(_ obj: TagListController?) { object = obj }
    
    @objc func colorPanelValueChanged(_ sender: NSColorPanel) {
        object?.colorPanelValueChanged(sender)
    }
}

final class TagListController: StackedPaneController {
    struct NotificationType {
        struct Name {
            static let tagPersistentStoreRequiresReloadNotification = NSNotification.Name(rawValue: "TagPersistentStoreRequiresReloadNotification")
        }
    }
    
    override var menuIdentifier: NSUserInterfaceItemIdentifier { NSUserInterfaceItemIdentifier("show-tag-manager") }
    
    private enum PreviewMode {
        case multiple
        case single
        case none
    }
    
    weak var selectDelegate                       : TagListSelectDelegate?
    var isSelectMode                              : Bool { selectDelegate != nil }
    
    private var previewMode                       : PreviewMode = .none
    private var previewContext                    : [String: Int]?
    
    weak var contentManager                       : ContentActionResponder?
    weak var importSource                         : TagImportSource?
    weak var sceneToolSource                      : SceneToolSource!
    {
        get { tableViewOverlay.sceneToolSource            }
        set { tableViewOverlay.sceneToolSource = newValue }
    }
    
    private static var sharedContext              : MRManagedObjectContext?
    private static var sharedUndoManager          : UndoManager = { return UndoManager() }()
    private var isContextLoaded                   : Bool          { TagListController.sharedContext != nil }
    
    @IBOutlet var internalController              : TagController!
    @IBOutlet var tagMenu                         : NSMenu!
    @IBOutlet var alertTextView                   : TagImportAlertView!
    
    @IBOutlet weak var paneTopConstraint          : NSLayoutConstraint!
    @IBOutlet weak var paneInnerTopConstraint     : NSLayoutConstraint!
    @IBOutlet weak var loadingErrorStack          : NSStackView!
    @IBOutlet weak var loadingErrorLabel          : NSTextField!
    @IBOutlet weak var buttonImport               : NSButton!
    @IBOutlet weak var buttonDeselectAll          : NSButton!
    @IBOutlet weak var buttonAdd                  : NSButton!
    @IBOutlet weak var buttonDelete               : NSButton!
    @IBOutlet weak var searchField                : NSSearchField!
    @IBOutlet weak var scrollView                 : NSScrollView!
    @IBOutlet weak var tableView                  : TagListTableView!
    @IBOutlet weak var tableViewOverlay           : TagListOverlayView!
    
    @IBOutlet weak var tableActionCustomView      : NSView!
    @IBOutlet weak var tableSearchCustomView      : NSView!
    @IBOutlet weak var tableContentCustomView     : NSView!
    
    @IBOutlet weak var tableColumnFlags           : NSTableColumn!
    @IBOutlet weak var tableColumnChecked         : NSTableColumn!
    @IBOutlet weak var tableColumnName            : NSTableColumn!
    
    private var lastStoredContentItems            : [ContentItem]?
    
    private var willUndoToken                     : NotificationToken?
    private var willRedoToken                     : NotificationToken?
    private var didUndoToken                      : NotificationToken?
    private var didRedoToken                      : NotificationToken?
    private var arrangedObjectsObservation        : NSKeyValueObservation?
    
    private var _selectModeDelayedRowIndexes      : IndexSet?
    override var undoManager                      : UndoManager?
    { isSelectMode ? selectDelegate?.undoManager : TagListController.sharedUndoManager }
    
    static         var attachPasteboardType = NSPasteboard.PasteboardType(rawValue: "private.jst.tag.attach")
    static private var inlinePasteboardType = NSPasteboard.PasteboardType(rawValue: "private.jst.tag.inline")
    
    private var disableTagReordering              : Bool = false
    private var disableTagEditing                 : Bool = false
    
    var isEditable                                : Bool {
        get {
            internalController.isEditable
        }
        set {
            internalController.isEditable = newValue
        }
    }
    
    private let observableKeys                    : [UserDefaults.Key] = [
        .disableTagReordering, .disableTagEditing,
    ]
    private var observables                       : [Observable]?
    
    // MARK: - Touch Bar
    
    private lazy var colorPanelTouchBar: NSTouchBar = {
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.customizationIdentifier = TagListController.colorPickerBar
        touchBar.defaultItemIdentifiers = [TagListController.colorPickerItem]
        touchBar.customizationAllowedItemIdentifiers = [TagListController.colorPickerItem]
        touchBar.principalItemIdentifier = TagListController.colorPickerItem
        return touchBar
    }()
    
    private var colorPanel: NSColorPanel {
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.isContinuous = true
        panel.touchBar = colorPanelTouchBar
        return panel
    }
    
    private func setupEmbeddedState(with context: NSManagedObjectContext? = nil) {
        paneBox.titlePosition               = isSelectMode ? .noTitle : .atTop
        paneBox.isTransparent               = isSelectMode
        paneTopConstraint.constant          = isSelectMode ? 0 : 4
        paneInnerTopConstraint.constant     = isSelectMode ? 0 : 8
        
        tableView.isEnabled                 = isContextLoaded
        tableView.isHidden                  = !isContextLoaded
        tableView.allowsMultipleSelection   = !isSelectMode
        tableView.gridStyleMask             = isSelectMode ? [] : [.solidVerticalGridLineMask]
        tableView.isEmbeddedMode            = isSelectMode
        tableView.contextUndoManager        = undoManager
        
        tableActionCustomView.isHidden      = isSelectMode
        tableColumnFlags.isHidden           = isSelectMode
        tableColumnChecked.isHidden         = !isSelectMode
        
        searchField.isEnabled               = isContextLoaded
        loadingErrorStack.isHidden          = isContextLoaded
        loadingErrorLabel.isHidden          = isContextLoaded
        loadingErrorLabel.stringValue       = isContextLoaded ? "" : NSLocalizedString("Unable to access tag database.", comment: "Setup Persistent Store")
        
        internalController.avoidsEmptySelection             = false
        internalController.preservesSelection               = true
        internalController.selectsInsertedObjects           = true
        internalController.clearsFilterPredicateOnInsertion = true
        internalController.automaticallyRearrangesObjects   = true
        internalController.alwaysUsesMultipleValuesMarker   = false
        internalController.entityName                       = "Tag"
        internalController.usesLazyFetching                 = false
        internalController.sortDescriptors                  = [NSSortDescriptor(key: "order", ascending: true)]
        internalController.managedObjectContext             = context
        internalController.automaticallyPreparesContent     = context != nil
        setupEditableState()
        
        if context != nil {
            internalController.prepareContent()
            internalController.rearrangeObjects()
        }
        
        arrangedObjectsObservation = internalController.observe(\.arrangedObjects, options: [.new], changeHandler: { [weak self] (target, change) in
            self?.reloadHeaderView()
        })
    }
    
    private func setupEditableState() {
        guard let sharedContext = TagListController.sharedContext else { return }
        sharedContext.failsOnSave = disableTagEditing
        isEditable = (isContextLoaded ? (!isSelectMode && !disableTagEditing) : false)
        
        if tableView.numberOfRows > 0 {
            tableView.reloadData(
                forRowIndexes: IndexSet(integersIn: 0..<tableView.numberOfRows),
                columnIndexes: IndexSet(integer: tableView.column(withIdentifier: .columnName))
            )
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableColumnChecked.headerCell = CheckboxHeaderCell()
        tableViewOverlay.dataSource = self
        tableViewOverlay.dragDelegate = self
        tableViewOverlay.tableRowHeight = tableView.rowHeight
        
        tableView.registerForDraggedTypes([TagListController.inlinePasteboardType])
        setupPersistentStore(byIgnoringError: false)
        
        prepareDefaults()
        observables = UserDefaults.standard.observe(keys: observableKeys, callback: { [weak self] in self?.applyDefaults($0, $1, $2) })
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(tagPersistentStoreRequiresReload(_:)),
            name: NotificationType.Name.tagPersistentStoreRequiresReloadNotification,
            object: nil
        )
    }
    
    private func prepareDefaults() {
        disableTagReordering = UserDefaults.standard[.disableTagReordering]
        disableTagEditing = UserDefaults.standard[.disableTagEditing]
        
        setupEditableState()
    }
    
    private func applyDefaults(_ defaults: UserDefaults, _ defaultKey: UserDefaults.Key, _ defaultValue: Any) {
        if let toValue = defaultValue as? Bool {
            if defaultKey == .disableTagReordering && disableTagReordering != toValue {
                disableTagReordering = toValue
            }
            else if defaultKey == .disableTagEditing && disableTagEditing != toValue {
                disableTagEditing = toValue
                
                setupEditableState()
            }
        }
    }
    
    @objc private func tagPersistentStoreRequiresReload(_ noti: Notification) {
        if let schemaURL = noti.userInfo?["url"] as? URL {
            setupPersistentStore(byIgnoringError: false, withCustomSchemaURL: schemaURL)
        } else {
            setupPersistentStore(byIgnoringError: true)
        }
    }
    
    func internalSetDeferredSelection(_ indexes: IndexSet) {
        _selectModeDelayedRowIndexes = indexes
    }
    
    @discardableResult
    private func _applyDeferredSelection() -> IndexSet? {
        let set = _selectModeDelayedRowIndexes
        if let set = set, tableView.selectedRowIndexes != set {
            tableView.selectRowIndexes(set, byExtendingSelection: false)
        }
        _cancelDeferredSelection()
        return set
    }
    
    @discardableResult
    private func _cancelDeferredSelection() -> IndexSet? {
        let originalSet = _selectModeDelayedRowIndexes
        _selectModeDelayedRowIndexes = nil
        return originalSet
    }
    
    func removeUndoRedoNotifications() {
        willUndoToken = nil
        willRedoToken = nil
        didUndoToken = nil
        didRedoToken = nil
        
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name.NSManagedObjectContextObjectsDidChange,
            object: nil
        )
    }
    
    func setupUndoRedoNotifications() {
        willUndoToken = NotificationCenter.default.observe(
            name: NSNotification.Name.NSUndoManagerWillUndoChange,
            object: undoManager
        ) { [unowned self] noti in
            if noti.object as? UndoManager == self.undoManager {
                if !self.isSelectMode {
                    self.setNeedsSaveManagedTags()
                }
            }
        }
        willRedoToken = NotificationCenter.default.observe(
            name: NSNotification.Name.NSUndoManagerWillRedoChange,
            object: undoManager
        ) { [unowned self] noti in
            if noti.object as? UndoManager == self.undoManager {
                if !self.isSelectMode {
                    self.setNeedsSaveManagedTags()
                }
            }
        }
        didUndoToken = NotificationCenter.default.observe(
            name: NSNotification.Name.NSUndoManagerDidUndoChange,
            object: undoManager
        ) { [unowned self] noti in
            if noti.object as? UndoManager == self.undoManager {
                if self.isSelectMode {
                    self.tableView.reloadData(
                        forRowIndexes: IndexSet(integersIn: 0..<self.tableView.numberOfRows),
                        columnIndexes: IndexSet(integer: self.tableView.column(withIdentifier: .columnChecked))
                    )
                    self.reloadHeaderView()
                    self._applyDeferredSelection()
                } else {
                    self.internalController.rearrangeObjects()
                }
            }
        }
        didRedoToken = NotificationCenter.default.observe(
            name: NSNotification.Name.NSUndoManagerDidRedoChange,
            object: undoManager
        ) { [unowned self] noti in
            if noti.object as? UndoManager == self.undoManager {
                if self.isSelectMode {
                    self.tableView.reloadData(
                        forRowIndexes: IndexSet(integersIn: 0..<self.tableView.numberOfRows),
                        columnIndexes: IndexSet(integer: self.tableView.column(withIdentifier: .columnChecked))
                    )
                    self.reloadHeaderView()
                    self._applyDeferredSelection()
                } else {
                    self.internalController.rearrangeObjects()
                }
            }
        }
        
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name.NSManagedObjectContextObjectsDidChange,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(managedTagsDidChangeNotification(_:)),
            name: NSNotification.Name.NSManagedObjectContextObjectsDidChange,
            object: nil
        )
    }
    
    private func setupPersistentStore(
        byIgnoringError ignore: Bool,
        withCustomSchemaURL customSchemaURL: URL? = nil
    ) {
        if let context = TagListController.sharedContext {
            self.setupEmbeddedState(with: context)
            self.setupUndoRedoNotifications()
        } else {
            TagListController.setupPersistentStore(withTagInitializer: { (context) -> ([Tag]) in
                let decoder = PropertyListDecoder()
                decoder.userInfo[CodingUserInfoKey.managedObjectContext] = context
                if let schemaURL = customSchemaURL ?? Bundle.main.url(forResource: "TagList-UI", withExtension: "plist")
                {
                    let schemaData = try Data(contentsOf: schemaURL)
                    let tags = try decoder.decode([Tag].self, from: schemaData)
                    return tags
                }
                return []
            }) { [weak self] (_ context: NSManagedObjectContext?, _ error: Error?) in
                
                guard let self = self else { return }
                
                if let context = context {
                    context.undoManager = TagListController.sharedUndoManager
                    self.setupEmbeddedState(with: context)
                    self.setupUndoRedoNotifications()
                } else if let error = error {
                    self.setupEmbeddedState()
                    self.removeUndoRedoNotifications()
                    
                    if !ignore {
                        self.presentError(error)
                    }
                    
                    debugPrint(error)
                }
            }
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        performReorderAndSave(isAsync: false)
        ensurePreviewedTagsForItems(lastStoredContentItems)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    static var persistentStoreURL: URL {
        guard let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last else {
            fatalError("unable to resolve library directory")
        }
        return docURL.appendingPathComponent("JSTColorPicker/TagList.sqlite")
    }
    
    static var persistentStoreDirectoryURL: URL {
        return persistentStoreURL.deletingLastPathComponent()
    }
    
    class func destoryPersistentStore() throws
    {
        if let coordinator = TagListController.sharedContext?.persistentStoreCoordinator {
            try coordinator.persistentStores.forEach({ try coordinator.remove($0) })
        }
        TagListController.sharedContext = nil

        let itemsToRemove = [
            persistentStoreURL,
            persistentStoreURL.deletingPathExtension().appendingPathExtension("sqlite-wal"),
            persistentStoreURL.deletingPathExtension().appendingPathExtension("sqlite-shm"),
        ]
        try itemsToRemove.forEach({ try FileManager.default.removeItem(at: $0) })
    }
    
    class func setupPersistentStore(withTagInitializer tagInitializer: @escaping (_ context: NSManagedObjectContext) throws -> ([Tag]), completionClosure: @escaping (NSManagedObjectContext?, Error?) -> ())
    {
        guard let tagModelURL = Bundle.main.url(forResource: "TagList", withExtension: "momd") else {
            fatalError("error loading model from bundle")
        }
        
        guard let tagModel = NSManagedObjectModel(contentsOf: tagModelURL) else {
            fatalError("error initializing model from \(tagModelURL)")
        }
        
        let context = MRManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: tagModel)
        context.persistentStoreCoordinator = coordinator
        
        let queue = DispatchQueue.global(qos: .background)
        queue.async {
            do {
                if FileManager.default.fileExists(atPath: persistentStoreURL.path) {
                    try coordinator.addPersistentStore(
                        ofType: NSSQLiteStoreType,
                        configurationName: nil,
                        at: persistentStoreURL,
                        options: nil
                    )
                } else {
                    try FileManager.default.createDirectory(
                        at: persistentStoreDirectoryURL,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                    try coordinator.addPersistentStore(
                        ofType: NSSQLiteStoreType,
                        configurationName: nil,
                        at: persistentStoreURL,
                        options: nil
                    )
                    
                    try tagInitializer(context).forEach { (tag) in
                        debugPrint(tag)
                    }
                    
                    try context.save()
                }
                
                TagListController.sharedContext = context
                
                DispatchQueue.main.sync {
                    completionClosure(context, nil)
                }
                
                NotificationCenter.default.post(
                    name: NSNotification.Name.NSManagedObjectContextDidLoad,
                    object: context
                )
            } catch {
                DispatchQueue.main.sync {
                    completionClosure(nil, error)
                }
            }
        }
    }
    
    
    // MARK: - Actions
    
    @IBAction private func delete(_ sender: Any) {
        let rows = ((tableView.clickedRow >= 0 && !tableView.selectedRowIndexes.contains(tableView.clickedRow)) ? IndexSet(integer: tableView.clickedRow) : IndexSet(tableView.selectedRowIndexes))
            .filteredIndexSet(includeInteger: { $0 < arrangedTags.count })
        internalController.remove(contentsOf: rows.map({ arrangedTags[$0] }))
    }
    
    @IBAction private func deselectAll(_ sender: Any) {
        tableView.deselectAll(sender)
    }
    
    private func importConfirmForTags(_ tagsToImport: [String]) -> Bool {
        let alert = NSAlert()
        if tagsToImport.count > 0 {
            alert.alertStyle = .warning
            alert.messageText = NSLocalizedString("Import Confirm", comment: "Import Confirm")
            alert.informativeText = String(format: NSLocalizedString("Do you want to import following %d tags from current document?", comment: "Import Confirm"), tagsToImport.count)
            if Bundle.main.loadNibNamed(String(describing: TagImportAlertView.self), owner: self, topLevelObjects: nil) {
                alertTextView.text = tagsToImport
                    .map({ "\u{25CF} " + $0 })
                    .joined(separator: "\n")
                alert.accessoryView = alertTextView
            }
            alert.addButton(withTitle: NSLocalizedString("Confirm", comment: "Import Confirm"))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Import Confirm"))
            return alert.runModal() == .alertFirstButtonReturn
        } else {
            alert.alertStyle = .informational
            alert.messageText = NSLocalizedString("Import Failed", comment: "Import Confirm")
            alert.informativeText = NSLocalizedString("No tag to import.", comment: "Import Confirm")
            alert.accessoryView = nil
            alert.addButton(withTitle: NSLocalizedString("OK", comment: "Import Confirm"))
            alert.runModal()
            return false
        }
    }
    
    @IBAction private func importTagBtnTapped(_ sender: Any) {
        
        guard let context = TagListController.sharedContext,
            let tagNames = importSource?.importableTagNames else
        {
            presentError(Content.Error.notLoaded)
            return
        }
        
        let arrangedTagNamesSet = Set(arrangedTags.map { $0.name })
        let missingNames = tagNames.filter { !arrangedTagNamesSet.contains($0) }
        
        guard importConfirmForTags(missingNames) else { return }
        
        do {
            
            let lastOrder = Int(arrangedTags.last?.order ?? 0)
            let lastRowIndex = tableView.numberOfRows - 1
            
            context.undoManager?.beginUndoGrouping()
            var idx = lastOrder
            missingNames.forEach { (tagName) in
                let obj = NSEntityDescription.insertNewObject(forEntityName: "Tag", into: context) as! Tag
                obj.order = Int64(idx)
                obj.name = tagName
                obj.colorHex = NSColor.random.sharpCSS
                idx += 1
            }
            
            try context.save()
            context.undoManager?.endUndoGrouping()
            
            let addedRowIndexes = IndexSet(integersIn: (lastRowIndex + 1)...(lastRowIndex + idx - lastOrder))
            if let lastAddedRowIndex = addedRowIndexes.last {
                tableView.selectRowIndexes(addedRowIndexes, byExtendingSelection: false)
                tableView.scrollRowToVisible(lastAddedRowIndex)
                makeFirstResponder(tableView)
            }
            
        } catch {
            presentError(error)
        }
    }
    
    @IBAction private func insertTagBtnTapped(_ sender: Any) {
        internalController.insert(sender)
        setNeedsReorderManagedTags()
        setNeedsSaveManagedTags()
    }
    
    @IBAction private func removeTagBtnTapped(_ sender: Any) {
        internalController.remove(sender)
        setNeedsSaveManagedTags()
    }
    
    @IBAction private func tagFieldValueChanged(_ sender: NSTextField) {
        setNeedsSaveManagedTags()
    }
    
    private func performReorderAndSave(isAsync async: Bool) {
        guard !isPaneHidden else {
            setNeedsReorderManagedTags()
            setNeedsSaveManagedTags()
            return
        }
        if async {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.reorderManagedTagsIfNeeded()
                self.saveManagedTagsIfNeeded()
                self.ensurePreviewedTagsForItems(self.lastStoredContentItems)
            }
        } else {
            reorderManagedTagsIfNeeded()
            saveManagedTagsIfNeeded()
            ensurePreviewedTagsForItems(lastStoredContentItems)
        }
    }
    
    @objc private func managedTagsDidChangeNotification(_ noti: NSNotification) {
        DispatchQueue.main.async { [weak self] in
            self?.performReorderAndSave(isAsync: true)
        }
    }
    
    private var shouldRearrangeManagedTags: Bool = false
    private var shouldSaveManagedTags: Bool = false
    
    private func setNeedsReorderManagedTags() {
        shouldRearrangeManagedTags = true
    }
    
    private func setNeedsSaveManagedTags() {
        shouldSaveManagedTags = true
    }
    
    private func saveManagedTagsIfNeeded() {
        guard let context = TagListController.sharedContext, shouldSaveManagedTags else { return }
        shouldSaveManagedTags = false
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch let error as NSError {
            if error.code == 133021,
                let itemName = ((context.insertedObjects.first ?? context.updatedObjects.first) as? Tag)?.name
            {
                presentError(Content.Error.itemExists(item: itemName))
            } else {
                presentError(error)
            }
            context.rollback()
        } catch {
            presentError(error)
            context.rollback()
        }
    }
    
    private func reorderManagedTagsIfNeeded() {
        guard shouldRearrangeManagedTags else { return }
        shouldRearrangeManagedTags = false
        guard let items = internalController.arrangedObjects as? [Tag] else { return }
        reorderTags(items)
    }
    
    private func reorderTags(_ items: [Tag]) {
        var itemIdx: Int64 = 0
        items.forEach({
            $0.order = itemIdx
            itemIdx += 1
        })
    }
    
    
    // MARK: - Menu
    
    private var menuTargetIndex: IndexSet.Element?
    private weak var menuTargetObject: Tag?
    
    @IBAction private func changeColorItemTapped(_ sender: NSMenuItem) {
        guard let targetIndex = (tableView.clickedRow >= 0 && !tableView.selectedRowIndexes.contains(tableView.clickedRow)) ? tableView.clickedRow : tableView.selectedRowIndexes.first else { return }
        
        menuTargetIndex = targetIndex
        menuTargetObject = arrangedTags[targetIndex]
        
        colorPanel.strongTarget = nil
        colorPanel.setAction(nil)
        colorPanel.color = NSColor(hex: arrangedTags[targetIndex].colorHex, alpha: 1.0)
        
        let wrapper = TagListControllerWrapper(self)
        colorPanel.strongTarget = wrapper
        colorPanel.setAction(#selector(colorPanelValueChanged(_:)))
        colorPanel.makeKeyAndOrderFront(self)
        
        tableView.selectRowIndexes(
            IndexSet(integer: targetIndex),
            byExtendingSelection: false
        )
    }
    
    @IBAction private func copyNameItemTapped(_ sender: NSMenuItem) {
        guard let targetIndex = (tableView.clickedRow >= 0 && !tableView.selectedRowIndexes.contains(tableView.clickedRow)) ? tableView.clickedRow : tableView.selectedRowIndexes.first else { return }
        
        ExportManager.exportToGeneralStringPasteboard(arrangedTags[targetIndex].name)
    }
    
    @IBAction private func copyColorItemTapped(_ sender: NSMenuItem) {
        guard let targetIndex = (tableView.clickedRow >= 0 && !tableView.selectedRowIndexes.contains(tableView.clickedRow)) ? tableView.clickedRow : tableView.selectedRowIndexes.first else { return }
        
        ExportManager.exportToGeneralStringPasteboard(arrangedTags[targetIndex].colorHex)
    }
    
    @objc func colorPanelValueChanged(_ sender: NSColorPanel) {
        
        guard !isPaneHidden else {
            menuTargetIndex = nil
            menuTargetObject = nil
            return
        }
        
        guard let index = menuTargetIndex,
            let tag = menuTargetObject,
            tag.managedObjectContext != nil else
        { return }
        
        tag.colorHex = sender.color.sharpCSS
        setNeedsSaveManagedTags()
        
        tableView.reloadData(
            forRowIndexes: IndexSet(integer: index),
            columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns)
        )
        
        if let colorPickerItem = colorPanelTouchBar.item(forIdentifier: TagListController.colorPickerItem) as? NSColorPickerTouchBarItem {
            colorPickerItem.color = sender.color
        }
    }
    
    
    // MARK: - Action
    
    @IBAction private func tableViewAction(_ sender: TagListTableView) { }
    
    @IBAction private func tableViewDoubleAction(_ sender: TagListTableView) { }
    
    private func reloadHeaderView() {
        guard let selectDelegate = selectDelegate else { return }
        if let headerCell = tableColumnChecked.headerCell as? CheckboxHeaderCell {
            headerCell.alternateState = selectDelegate.fetchAlternateStateForTags(arrangedTags)
            tableView.headerView?.needsDisplay = true
        }
    }
    
    @IBAction private func checkedButtonAction(_ sender: NSButton) {
        if sender.allowsMixedState { sender.allowsMixedState = false }
        guard let selectDelegate = selectDelegate else { return }
        let checkedRow = tableView.row(for: sender)
        makeFirstResponder(tableView)
        tableView.selectRowIndexes(IndexSet(integer: checkedRow), byExtendingSelection: false)
        selectDelegate.selectedStateChanged(of: arrangedTags[checkedRow].name, to: sender.state)
        reloadHeaderView()
    }
    
    @IBAction private func resetButtonAction(_ sender: NSButton) {
        NotificationCenter.default.post(name: PreferencesController.makeKeyAndOrderFrontNotification, object: self, userInfo: ["viewIdentifier": AdvancedController.Identifier])
    }
    
}

extension TagListController: TagListSource {
    
    var arrangedTagController: TagController { internalController }
    var arrangedTags: [Tag] { internalController.arrangedObjects as? [Tag] ?? [] }
    var managedObjectContext: NSManagedObjectContext? { TagListController.sharedContext }
    
    func managedTag(of name: String) -> Tag? {
        
        if arrangedTags.count > 0 && internalController.filterPredicate == nil {
            return arrangedTags.first(where: { $0.name == name })
        }
        
        guard let context = TagListController.sharedContext else { return nil }
        
        do {
            
            let sort = NSSortDescriptor(key: #keyPath(Tag.order), ascending: true)
            let fetchRequest = NSFetchRequest<Tag>.init(entityName: "Tag")
            fetchRequest.fetchLimit = 1
            fetchRequest.predicate = NSPredicate(format: "name == %@", name)
            fetchRequest.sortDescriptors = [sort]
            
            return (try context.fetch(fetchRequest)).first
            
        } catch {
            debugPrint(error)
        }
        
        return nil
    }
    
    func managedTags(of names: [String]) -> [Tag] {
        
        if arrangedTags.count > 0 && internalController.filterPredicate == nil {
            return arrangedTags.filter({ names.contains($0.name) })
        }
        
        guard let context = TagListController.sharedContext else { return [] }
        do {
            
            var predicates: [NSPredicate] = []
            for name in names {
                predicates.append(NSPredicate(format: "name == %@", name))
            }
            let sort = NSSortDescriptor(key: #keyPath(Tag.order), ascending: true)
            let fetchRequest = NSFetchRequest<Tag>.init(entityName: "Tag")
            fetchRequest.fetchLimit = names.count
            fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
            fetchRequest.sortDescriptors = [sort]
            
            return try context.fetch(fetchRequest)
            
        } catch {
            debugPrint(error)
        }
        
        return []
    }
    
    var selectedTags: [Tag] {
        arrangedTagController.selectedObjects as! [Tag]
    }
    
    var selectedTagNames: [String] {
        return selectedTags.map({ $0.name })
    }
    
}

extension TagListController: TagListDragDelegate {
    
    var shouldPerformDragging: Bool { isContextLoaded && !isSelectMode }
    
    func willPerformDragging(_ sender: Any?) -> Bool {
        contentManager?.deselectAllContentItems()
        return shouldPerformDragging
    }
    
    var selectedRowIndexes: IndexSet { tableView.selectedRowIndexes }
    
    func selectedRowIndexes(at point: CGPoint, shouldHighlight: Bool) -> IndexSet {
        var indexes = tableView.selectedRowIndexes
        let rowAtPoint = tableView.row(at: scrollView.convert(point, to: tableView))
        if rowAtPoint >= 0 {
            if !indexes.contains(rowAtPoint) {
                let theIndexSet = IndexSet(integer: rowAtPoint)
                tableView.selectRowIndexes(theIndexSet, byExtendingSelection: false)
                indexes = theIndexSet
            }
        } else {
            indexes = IndexSet()
        }
        if shouldHighlight {
            makeFirstResponder(tableView)
        }
        return indexes
    }
    
    func visibleRects(of rowIndexes: IndexSet) -> [CGRect] {
        var rects = [CGRect]()
        var prevRect: CGRect = .null
        for rowIndex in rowIndexes {
            let rect = tableView.rect(ofRow: rowIndex)
            if !rect.offsetBy(dx: 0.0, dy: -0.1)
                .intersects(prevRect)
            {
                if !prevRect.isNull { rects.append(prevRect) }
                prevRect = rect
            } else {
                prevRect = prevRect.union(rect)
            }
        }
        if !prevRect.isNull { rects.append(prevRect) }
        return rects.map({ scrollView.convert($0, from: tableView) })
    }
    
}

extension TagListController: NSTableViewDelegate, NSTableViewDataSource {
    
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard !isSelectMode, case .idle = tableViewOverlay.state else { return nil }
        let item = NSPasteboardItem()
        let tag = arrangedTags[row]
        item.setPropertyList([
            "row": row,
            "name": tag.name,
            "defaultUserInfo": tag.defaultUserInfo,
        ], forType: TagListController.inlinePasteboardType)
        return item
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if disableTagReordering || disableTagEditing {
            return []
        }
        guard case .idle = tableViewOverlay.state else { return [] }
        guard internalController.filterPredicate == nil else { return [] }
        if dropOperation == .above {
            return .move
        }
        return []
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard case .idle = tableViewOverlay.state else { return false }
        var collection = arrangedTags
        
        var oldIndexes = [Int]()
        info.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:]) { dragItem, _, _ in
            if let obj = (dragItem.item as! NSPasteboardItem).propertyList(forType: TagListController.inlinePasteboardType) as? [String: Any],
                let index = obj["row"] as? Int
            {
                oldIndexes.append(index)
            }
        }

        var oldIndexOffset = 0
        var newIndexOffset = 0

        // For simplicity, the code below uses `tableView.moveRowAtIndex` to move rows around directly.
        // You may want to move rows in your content array and then call `tableView.reloadData()` instead.
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        
        tableView.beginUpdates()
        for oldIndex in oldIndexes {
            if oldIndex < row {
                let tag = collection.remove(at: oldIndex + oldIndexOffset)
                collection.insert(tag, at: row - 1)
                tableView.moveRow(at: oldIndex + oldIndexOffset, to: row - 1)
                oldIndexOffset -= 1
            } else {
                let tag = collection.remove(at: oldIndex)
                collection.insert(tag, at: row + newIndexOffset)
                tableView.moveRow(at: oldIndex, to: row + newIndexOffset)
                newIndexOffset += 1
            }
        }
        tableView.endUpdates()
        
        NSAnimationContext.endGrouping()
        
        reorderTags(collection)
        internalController.content = NSMutableArray(array: collection)
        
        setNeedsSaveManagedTags()
        return true
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return arrangedTags.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn, row < arrangedTags.count else { return nil }
        if let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as? TagCellView {
            let col = tableColumn.identifier
            if col == .columnFlags {
                if previewMode == .none {
                    cell.text = "-"
                }
                else {
                    let tagName = arrangedTags[row].name
                    if let tagCount = previewContext?[tagName] {
                        if previewMode == .multiple {
                            cell.text = String(tagCount)
                        }
                        else if previewMode == .single {
                            cell.text = "\u{25CF}"
                        }
                    } else {
                        cell.text = ""
                    }
                }
            }
            else if col == .columnChecked,
                let selectDelegate = selectDelegate
            {
                let tagName = arrangedTags[row].name
                cell.state = selectDelegate.selectedState(of: tagName)
            }
            else if col == .columnName {
                cell.isEditable = !isSelectMode && isEditable
            }
            return cell
        }
        return nil
    }

    func tableView(_ tableView: NSTableView, typeSelectStringFor tableColumn: NSTableColumn?, row: Int) -> String? {
        guard let tableColumn = tableColumn, row < arrangedTags.count else { return nil }
        let col = tableColumn.identifier
        if col == .columnName {
            return arrangedTags[row].name
        }
        return nil
    }
    
    func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
        guard let selectDelegate = selectDelegate else { return }
        if tableColumn == tableColumnChecked {
            if let headerCell = tableColumn.headerCell as? CheckboxHeaderCell {
                selectDelegate.setupAlternateState(headerCell.toggleAlternateState(), forTags: arrangedTags)
                tableView.reloadData(
                    forRowIndexes: IndexSet(integersIn: 0..<tableView.numberOfRows),
                    columnIndexes: IndexSet(integer: tableView.column(withIdentifier: .columnChecked))
                )
            }
        }
    }
    
}

extension TagListController: NSMenuItemValidation, NSMenuDelegate {
    
    private var hasAttachedSheet: Bool { view.window?.attachedSheet != nil }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard !hasAttachedSheet else { return false }
        if menuItem.action == #selector(changeColorItemTapped(_:)) || menuItem.action == #selector(copyNameItemTapped(_:)) || menuItem.action == #selector(copyColorItemTapped(_:)) {
            if menuItem.action == #selector(changeColorItemTapped(_:)) {
                guard !isSelectMode && isEditable else { return false }
            }
            guard tableView.clickedRow >= 0 else { return false }
            if tableView.selectedRowIndexes.count > 1 && tableView.selectedRowIndexes.contains(tableView.clickedRow) { return false }
            return true
        }
        else if menuItem.action == #selector(delete(_:)) {
            guard !isSelectMode && isEditable else { return false }
            return tableView.clickedRow >= 0 || tableView.selectedRowIndexes.count > 0
        }
        return false
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        applyKeyBindingsToTopLevelContextMenu(menu)
    }
    
    // Apply key bindings for top-level menus.
    private func applyKeyBindingsToTopLevelContextMenu(_ menu: NSMenu) {
        if menu == tagMenu {
            MenuKeyBindingManager.shared.applyKeyBindingsToMenu(menu)
        }
    }
}

extension TagListController: TagListPreviewDelegate {

    private func scrollToFirstCheckedRow() {
        if let row = arrangedTags.firstIndex(where: { previewContext?.keys.contains($0.name) ?? false }) {
            tableView.scrollRowToVisible(row)
        }
    }
    
    private func ensurePreviewedTagsForItems(_ items: [ContentItem]?) {
        guard let items = items else { return }
        previewTags(for: items)
    }
    
    func previewTags(for items: [ContentItem]) {
        lastStoredContentItems = items
        guard !isPaneHidden else {
            return
        }
        if items.count > 0 {
            previewMode = items.count == 1 ? .single : .multiple
            previewContext = Dictionary(counted: items.flatMap({ $0.tags }))
        }
        else {
            previewMode = .none
            previewContext = nil
        }
        let col = tableView.column(withIdentifier: .columnFlags)
        tableView.reloadData(
            forRowIndexes: IndexSet(integersIn: 0..<tableView.numberOfRows),
            columnIndexes: col >= 0 ? IndexSet(integer: col) : IndexSet()
        )
        scrollToFirstCheckedRow()
    }
    
}

extension TagListController: ShortcutGuideDataSource {
    
    var shortcutItems: [ShortcutItem] {
        return []
    }

}

extension TagListController: NSTouchBarDelegate {
    
    private static let colorPickerBar = NSTouchBar.CustomizationIdentifier("com.jst.colorPickerBar")
    private static let colorPickerItem = NSTouchBarItem.Identifier("com.jst.TouchBarItem.color")
    
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        let colorPickerItem: NSColorPickerTouchBarItem
        
        switch identifier {
        case TagListController.colorPickerItem:
            colorPickerItem = NSColorPickerTouchBarItem.colorPicker(withIdentifier: identifier)
            colorPickerItem.showsAlpha = false
            colorPickerItem.color = colorPanel.color
            colorPickerItem.allowedColorSpaces = [.sRGB]
        default:
            return nil
        }
        
        colorPickerItem.customizationLabel = NSLocalizedString("Choose Color", comment: "NSColorPanel")
        colorPickerItem.target = self
        colorPickerItem.action = #selector(colorTouchBarValueChanged(_:))
        
        return colorPickerItem
    }
    
    @objc func colorTouchBarValueChanged(_ sender: NSColorPickerTouchBarItem) {
        colorPanel.color = sender.color
    }
    
}

