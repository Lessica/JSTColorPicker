//
//  TagListController.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/5/24.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

extension NSUserInterfaceItemIdentifier {
    static let columnFlags      = NSUserInterfaceItemIdentifier("col-flags")
    static let columnChecked    = NSUserInterfaceItemIdentifier("col-checked")
    static let columnName       = NSUserInterfaceItemIdentifier("col-name")
}

enum TagListHighlightMode {
    case multiple
    case single
    case none
}

class TagListController: NSViewController {
    
    public weak var embeddedDelegate: TagListEmbedDelegate?
    public var isEmbeddedMode: Bool { embeddedDelegate != nil }
    private var isDatabaseLoaded: Bool = false {
        didSet { reloadEmbeddedState(isDatabaseLoaded) }
    }
    
    private var highlightMode = TagListHighlightMode.none
    private var highlightContext: [String: Int]?
    
    public weak var contentDelegate   : ContentDelegate?
    public weak var importItemSource  : TagImportSource?
    public weak var sceneToolSource   : SceneToolSource!
    {
        get { tableViewOverlay.sceneToolSource }
        set { tableViewOverlay.sceneToolSource = newValue }
    }
    
    @IBOutlet var internalContext             : NSManagedObjectContext!  // FIXME: move to a shared space
    @IBOutlet var internalController          : TagController!           // FIXME: move to a shared space
    @IBOutlet var tagMenu                     : NSMenu!
    @IBOutlet var alertTextView               : AlertTextView!
    @IBOutlet weak var loadingErrorLabel      : NSTextField!
    @IBOutlet weak var searchField            : NSSearchField!
    @IBOutlet weak var scrollView             : NSScrollView!
    @IBOutlet weak var tableView              : TagListTableView!
    @IBOutlet weak var tableViewOverlay       : TagListOverlayView!
    
    @IBOutlet weak var tableActionCustomView  : NSView!
    @IBOutlet weak var tableSearchCustomView  : NSView!
    @IBOutlet weak var tableContentCustomView : NSView!
    
    @IBOutlet weak var tableColumnFlags       : NSTableColumn!
    @IBOutlet weak var tableColumnChecked     : NSTableColumn!
    @IBOutlet weak var tableColumnName        : NSTableColumn!
    
    private var willUndoToken: NotificationToken?
    private var willRedoToken: NotificationToken?
    private var didUndoToken : NotificationToken?
    private var didRedoToken : NotificationToken?
    
    static public var attachPasteboardType = NSPasteboard.PasteboardType(rawValue: "private.jst.tag.attach")
    static private var inlinePasteboardType = NSPasteboard.PasteboardType(rawValue: "private.jst.tag.inline")
    
    private var colorPanel: NSColorPanel {
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.isContinuous = false
        return panel
    }
    
    private func reloadEmbeddedState(_ state: Bool) {
        tableView.isEmbeddedMode            = isEmbeddedMode
        tableActionCustomView.isHidden      = isEmbeddedMode
        tableColumnFlags.isHidden           = isEmbeddedMode
        tableColumnChecked.isHidden         = !isEmbeddedMode
        internalController.isEditable       = state ? !isEmbeddedMode : false
        searchField.isEnabled               = state
        tableView.isEnabled                 = state
        tableView.isHidden                  = !state
        tableView.allowsMultipleSelection   = !isEmbeddedMode
        tableView.gridStyleMask             = isEmbeddedMode ? [] : [.solidVerticalGridLineMask]
        loadingErrorLabel.isHidden          = state
        loadingErrorLabel.stringValue       = state ? "" : NSLocalizedString("Unable to access tag database.", comment: "Setup Persistent Store")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableViewOverlay.dataSource = self
        tableViewOverlay.dragDelegate = self
        tableViewOverlay.tableRowHeight = tableView.rowHeight
        
        internalController.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        tableView.registerForDraggedTypes([TagListController.inlinePasteboardType])
        
        willUndoToken = NotificationCenter.default.observe(name: NSNotification.Name.NSUndoManagerWillUndoChange, object: undoManager, using: { [unowned self] _ in
            self.setNeedsSaveManagedTags()
        })
        willRedoToken = NotificationCenter.default.observe(name: NSNotification.Name.NSUndoManagerWillRedoChange, object: undoManager, using: { [unowned self] _ in
            self.setNeedsSaveManagedTags()
        })
        
        didUndoToken = NotificationCenter.default.observe(name: NSNotification.Name.NSUndoManagerDidUndoChange, object: undoManager) { [unowned self] _ in
            self.internalController.rearrangeObjects()
        }
        didRedoToken = NotificationCenter.default.observe(name: NSNotification.Name.NSUndoManagerDidRedoChange, object: undoManager) { [unowned self] _ in
            self.internalController.rearrangeObjects()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(managedTagsDidChangeNotification(_:)), name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: nil)
        
        let embeddedMode = self.isEmbeddedMode
        setupPersistentStore(withInitialTags: { () -> ([(String, String)]) in
            return embeddedMode ? [] : [
                
                /* Controls */
                ("Button",         "#171E6D"),
                ("Switch",         "#1E3388"),
                ("Slider",         "#27539B"),
                ("Checkbox",       "#3073AE"),
                ("Radio",          "#3993C2"),
                ("TextField",      "#42B3D5"),
                ("Rate",           "#75C6D1"),
                ("BackTop",        "#A9DACC"),
                
                /* Displays */
                ("Label",          "#044E48"),
                ("Badge",          "#06746B"),
                ("Media",          "#20876B"),
                ("Box",            "#6A9A48"),
                ("Hud",            "#B5AC23"),
                ("Keyboard",       "#E6B80B"),
                ("Progress",       "#FACA3E"),
                ("Spin",           "#FFDF80"),
                
                /* Layouts */
                ("StatusBar",      "#661900"),
                ("TabBar",         "#B22C00"),
                ("NavigationBar",  "#E6450F"),
                ("Skeleton",       "#FF6500"),
                ("Notification",   "#FF8C00"),
                
                /* Status */
                ("Disabled",       "#657899"),
                ("Active",         "#1C314E"),
                
            ]
        }) { [weak self] (_ error: Error?) in
            if let error = error {
                self?.isDatabaseLoaded = false
                self?.presentError(error)
                return
            }
            self?.internalContext.undoManager = self?.undoManager
            self?.isDatabaseLoaded = true
            self?.internalController.rearrangeObjects()
        }
        
    }
    
    private func setupPersistentStore(withInitialTags: @escaping () -> ([(String, String)]), completionClosure: @escaping (Error?) -> ()) {
        guard let tagModelURL = Bundle.main.url(forResource: "TagList", withExtension: "momd") else {
            fatalError("error loading model from bundle")
        }
        
        guard let tagModel = NSManagedObjectModel(contentsOf: tagModelURL) else {
            fatalError("error initializing model from \(tagModelURL)")
        }
        
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: tagModel)
        internalContext.persistentStoreCoordinator = coordinator
        
        guard let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last else {
            fatalError("unable to resolve library directory")
        }
        
        let queue = DispatchQueue.global(qos: .background)
        queue.async { [weak self] in
            
            do {
                
                let storeURL = docURL.appendingPathComponent("JSTColorPicker/TagList.sqlite")
                if FileManager.default.fileExists(atPath: storeURL.path) {
                    
                    try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
                    
                } else {
                    
                    try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                    try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
                    
                    if let self = self {
                        
                        var idx = 1
                        withInitialTags().forEach { (tag) in
                            let obj = NSEntityDescription.insertNewObject(forEntityName: "Tag", into: self.internalContext) as! Tag
                            obj.order = Int64(idx)
                            obj.name = tag.0
                            obj.colorHex = tag.1
                            idx += 1
                        }
                        
                        do {
                            try self.internalContext.save()
                        } catch {
                            DispatchQueue.main.sync {
                                completionClosure(error)
                            }
                        }
                        
                    }
                    
                }
                
                DispatchQueue.main.sync {
                    NotificationCenter.default.post(name: NSNotification.Name.NSManagedObjectContextDidLoad, object: self?.internalContext)
                    completionClosure(nil)
                }
            } catch {
                DispatchQueue.main.sync {
                    completionClosure(error)
                }
            }
            
        }
    }
    
    
    // MARK: - Actions
    
    @IBAction func delete(_ sender: Any) {
        let rows = ((tableView.clickedRow >= 0 && !tableView.selectedRowIndexes.contains(tableView.clickedRow)) ? IndexSet(integer: tableView.clickedRow) : IndexSet(tableView.selectedRowIndexes))
            .filteredIndexSet(includeInteger: { $0 < arrangedTags.count })
        internalController.remove(contentsOf: rows.map({ arrangedTags[$0] }))
    }
    
    private func importConfirmForTags(_ tagsToImport: [String]) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        if tagsToImport.count > 0 {
            alert.messageText = NSLocalizedString("Import Confirm", comment: "Import Confirm")
            alert.informativeText = String(format: NSLocalizedString("Do you want to import following %d tags from current document?", comment: "Import Confirm"), tagsToImport.count)
            if Bundle.main.loadNibNamed("AlertTextView", owner: self, topLevelObjects: nil) {
                alertTextView.text = tagsToImport
                    .map({ "\u{25CF} " + $0 })
                    .joined(separator: "\n")
                alert.accessoryView = alertTextView
            }
            alert.addButton(withTitle: NSLocalizedString("Confirm", comment: "Import Confirm"))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Import Confirm"))
            return alert.runModal() == .alertFirstButtonReturn
        } else {
            alert.messageText = NSLocalizedString("Import Failed", comment: "Import Confirm")
            alert.informativeText = NSLocalizedString("No tag to import", comment: "Import Confirm")
            alert.accessoryView = nil
            alert.addButton(withTitle: NSLocalizedString("OK", comment: "Import Confirm"))
            alert.runModal()
            return false
        }
    }
    
    @IBAction private func importTagBtnTapped(_ sender: Any) {
        guard let tagNames = importItemSource?.importableTagNames else {
            presentError(ContentError.noDocumentLoaded)
            return
        }
        
        let arrangedTagNamesSet = Set(arrangedTags.map { $0.name })
        let missingNames = tagNames.filter { !arrangedTagNamesSet.contains($0) }
        
        guard importConfirmForTags(missingNames) else { return }
        
        do {
            let lastOrder = arrangedTags.last?.order ?? 0
            
            var idx = lastOrder
            missingNames.forEach { (tagName) in
                let obj = NSEntityDescription.insertNewObject(forEntityName: "Tag", into: self.internalContext) as! Tag
                obj.order = Int64(idx)
                obj.name = tagName
                obj.colorHex = NSColor.random.sharpCSS
                idx += 1
            }
            
            try self.internalContext.save()
        } catch {
            presentError(error)
        }
    }
    
    @IBAction private func insertTagBtnTapped(_ sender: Any) {
        internalController.insert(sender)
        setNeedsRearrangeManagedTags()
        setNeedsSaveManagedTags()
    }
    
    @IBAction private func removeTagBtnTapped(_ sender: Any) {
        internalController.remove(sender)
        setNeedsSaveManagedTags()
    }
    
    @IBAction private func tagFieldValueChanged(_ sender: NSTextField) {
        setNeedsSaveManagedTags()
    }
    
    @objc private func managedTagsDidChangeNotification(_ noti: NSNotification) {
        DispatchQueue.main.async { [weak self] in
            self?.rearrangeManagedTagsIfNeeded()
            self?.saveManagedTagsIfNeeded()
        }
    }
    
    private var shouldRearrangeManagedTags: Bool = false
    private var shouldSaveManagedTags: Bool = false
    
    private func setNeedsRearrangeManagedTags() {
        shouldRearrangeManagedTags = true
    }
    
    private func setNeedsSaveManagedTags() {
        shouldSaveManagedTags = true
    }
    
    private func saveManagedTagsIfNeeded() {
        guard shouldSaveManagedTags else { return }
        shouldSaveManagedTags = false
        guard internalContext.hasChanges else { return }
        do {
            try internalContext.save()
        } catch let error as NSError {
            if error.code == 133021, let itemName = ((internalContext.insertedObjects.first ?? internalContext.updatedObjects.first) as? Tag)?.name {
                presentError(ContentError.itemExists(item: itemName))
            } else {
                presentError(error)
            }
            internalContext.rollback()
        } catch {
            presentError(error)
            internalContext.rollback()
        }
    }
    
    private func rearrangeManagedTagsIfNeeded() {
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
    
    private weak var menuTargetObject: Tag?
    
    @IBAction private func changeColorItemTapped(_ sender: NSMenuItem) {
        guard let targetIndex = (tableView.clickedRow >= 0 && !tableView.selectedRowIndexes.contains(tableView.clickedRow)) ? tableView.clickedRow : tableView.selectedRowIndexes.first else { return }
        
        menuTargetObject = arrangedTags[targetIndex]
        
        colorPanel.setTarget(nil)
        colorPanel.setAction(nil)
        colorPanel.color = NSColor(css: arrangedTags[targetIndex].colorHex, alpha: 1.0)
        
        colorPanel.setTarget(self)
        colorPanel.setAction(#selector(colorPanelValueChanged(_:)))
        colorPanel.orderFront(sender)
    }
    
    @objc private func colorPanelValueChanged(_ sender: NSColorPanel) {
        guard let tag = menuTargetObject, tag.managedObjectContext != nil else { return }
        tag.colorHex = sender.color.sharpCSS
        setNeedsSaveManagedTags()
    }
    
    
    // MARK: - Action
    
    @IBAction func tableViewAction(_ sender: TagListTableView) { }
    
    @IBAction func tableViewDoubleAction(_ sender: TagListTableView) { }
    
    @IBAction func checkedButtonAction(_ sender: NSButton) {
        if sender.allowsMixedState { sender.allowsMixedState = false }
        guard let embeddedDelegate = embeddedDelegate else { return }
        let checkedRow = tableView.row(for: sender)
        embeddedDelegate.embedStateChanged(of: arrangedTags[checkedRow].name, to: sender.state)
    }
    
}

extension TagListController: TagListSource {
    
    var arrangedTagController: TagController { internalController }
    var arrangedTags: [Tag] { internalController.arrangedObjects as? [Tag] ?? [] }
    
    var managedObjectContext: NSManagedObjectContext { internalContext }
    func managedTag(of name: String) -> Tag? {
        if arrangedTags.count > 0 {
            return arrangedTags.first(where: { $0.name == name })
        }
        do {
            let sort = NSSortDescriptor(key: #keyPath(Tag.order), ascending: true)
            let fetchRequest = NSFetchRequest<Tag>.init(entityName: "Tag")
            fetchRequest.fetchLimit = 1
            fetchRequest.predicate = NSPredicate(format: "name == %@", name)
            fetchRequest.sortDescriptors = [sort]
            let fetchedTags = try internalContext.fetch(fetchRequest)
            return fetchedTags.first
        } catch {
            debugPrint(error)
        }
        return nil
    }
    func managedTags(of names: [String]) -> [Tag] {
        if arrangedTags.count > 0 {
            return arrangedTags.filter({ names.contains($0.name) })
        }
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
            let fetchedTags = try internalContext.fetch(fetchRequest)
            return fetchedTags
        } catch {
            debugPrint(error)
        }
        return []
    }
    
}

extension TagListController: TagListDragDelegate {
    
    var shouldPerformDragging: Bool { !isEmbeddedMode && internalController.isEditable }
    
    func willPerformDragging(_ sender: Any?) -> Bool {
        contentDelegate?.deselectAllContentItems()
        return internalController.isEditable
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
        guard !isEmbeddedMode, case .idle = tableViewOverlay.state else { return nil }
        let item = NSPasteboardItem()
        item.setPropertyList([
            "row": row,
            "name": arrangedTags[row].name
        ], forType: TagListController.inlinePasteboardType)
        return item
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
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
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn else { return nil }
        if let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as? TagCellView {
            let col = tableColumn.identifier
            if col == .columnFlags {
                if highlightMode == .none {
                    cell.text = "-"
                }
                else {
                    let tagName = arrangedTags[row].name
                    if let tagCount = highlightContext?[tagName] {
                        if highlightMode == .multiple {
                            cell.text = String(tagCount)
                        }
                        else if highlightMode == .single {
                            cell.text = "\u{25CF}"
                        }
                    } else {
                        cell.text = ""
                    }
                }
            }
            else if col == .columnChecked,
                let embeddedDelegate = embeddedDelegate
            {
                let tagName = arrangedTags[row].name
                cell.state = embeddedDelegate.embedState(of: tagName)
            }
            else if col == .columnName {
                cell.isEditable = !isEmbeddedMode
            }
            return cell
        }
        return nil
    }
    
}

extension TagListController: NSMenuItemValidation, NSMenuDelegate {
    
    private var hasAttachedSheet: Bool {
        return view.window?.attachedSheet != nil
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard !hasAttachedSheet else { return false }
        if menuItem.action == #selector(changeColorItemTapped(_:)) {
            guard tableView.clickedRow >= 0 else { return false }
            if tableView.selectedRowIndexes.count > 1 && tableView.selectedRowIndexes.contains(tableView.clickedRow) { return false }
            return true
        }
        else if menuItem.action == #selector(delete(_:)) {
            return tableView.clickedRow >= 0 || tableView.selectedRowIndexes.count > 0
        }
        return false
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu == tagMenu {}
    }
    
}

extension TagListController: TagListPreviewDelegate {
    
    func highlightTags(for items: [ContentItem]) {
        if items.count > 0 {
            highlightMode = items.count == 1 ? .single : .multiple
            highlightContext = Dictionary(counted: items.flatMap({ $0.tags }))
        }
        else {
            highlightMode = .none
            highlightContext = nil
        }
        let col = tableView.column(withIdentifier: .columnFlags)
        tableView.reloadData(
            forRowIndexes: IndexSet(integersIn: 0..<tableView.numberOfRows),
            columnIndexes: col >= 0 ? IndexSet(integer: col) : IndexSet()
        )
    }
    
    @discardableResult
    private func internalHighlightTags(for items: [ContentItem]) -> IndexSet? {
        return nil
    }
    
}

