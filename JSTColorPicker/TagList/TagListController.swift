//
//  TagListController.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/5/24.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa
import ShortcutGuide

extension NSUserInterfaceItemIdentifier {
    static let columnFlags      = NSUserInterfaceItemIdentifier("col-flags")
    static let columnChecked    = NSUserInterfaceItemIdentifier("col-checked")
    static let columnName       = NSUserInterfaceItemIdentifier("col-name")
}

@objc private class TagListControllerWrapper: NSObject {
    
    public weak var object: TagListController?
    init(_ obj: TagListController?) { object = obj }
    
    @objc internal func colorPanelValueChanged(_ sender: NSColorPanel) {
        object?.colorPanelValueChanged(sender)
    }
    
}

class TagListController: NSViewController {
    
    private enum PreviewMode {
        case multiple
        case single
        case none
    }
    
    public weak var editDelegate                  : TagListEditDelegate?
    public var isEditMode                         : Bool { editDelegate != nil }
    
    private var previewMode                       : PreviewMode = .none
    private var previewContext                    : [String: Int]?
    
    public weak var contentManager                : ContentDelegate?
    public weak var importSource                  : TagImportSource?
    public weak var sceneToolSource               : SceneToolSource!
    {
        get { tableViewOverlay.sceneToolSource            }
        set { tableViewOverlay.sceneToolSource = newValue }
    }
    
    private static var sharedContext              : NSManagedObjectContext?
    private static var sharedUndoManager          : UndoManager = { return UndoManager() }()
    private var isContextLoaded                   : Bool          { TagListController.sharedContext != nil }
    
    @IBOutlet var internalController              : TagController!
    @IBOutlet var tagMenu                         : NSMenu!
    @IBOutlet var alertTextView                   : AlertTextView!
    @IBOutlet weak var loadingErrorLabel          : NSTextField!
    @IBOutlet weak var buttonImport               : NSButton!
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
    
    private var willUndoToken                     : NotificationToken?
    private var willRedoToken                     : NotificationToken?
    private var didUndoToken                      : NotificationToken?
    private var didRedoToken                      : NotificationToken?
    
    static public var attachPasteboardType  = NSPasteboard.PasteboardType(rawValue: "private.jst.tag.attach")
    static private var inlinePasteboardType = NSPasteboard.PasteboardType(rawValue: "private.jst.tag.inline")
    
    private var colorPanel: NSColorPanel {
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.isContinuous = false
        return panel
    }
    
    private func setupEmbeddedState(with context: NSManagedObjectContext? = nil) {
        tableView.isEnabled                 = isContextLoaded
        tableView.isHidden                  = !isContextLoaded
        tableView.allowsMultipleSelection   = !isEditMode
        tableView.gridStyleMask             = isEditMode ? [] : [.solidVerticalGridLineMask]
        tableView.isEmbeddedMode            = isEditMode
        tableView.contextUndoManager        = TagListController.sharedUndoManager
        
        tableActionCustomView.isHidden      = isEditMode
        tableColumnFlags.isHidden           = isEditMode
        tableColumnChecked.isHidden         = !isEditMode
        
        searchField.isEnabled               = isContextLoaded
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
        internalController.isEditable                       = isContextLoaded ? !isEditMode : false
        internalController.managedObjectContext             = context
        internalController.automaticallyPreparesContent     = context != nil
        
        if context != nil {
            internalController.prepareContent()
            internalController.rearrangeObjects()
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableViewOverlay.dataSource = self
        tableViewOverlay.dragDelegate = self
        tableViewOverlay.tableRowHeight = tableView.rowHeight
        
        tableView.registerForDraggedTypes([TagListController.inlinePasteboardType])
        
        if let context = TagListController.sharedContext {
            
            self.setupEmbeddedState(with: context)
            
            if let undoManager = tableView.contextUndoManager {
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
            }
            
            NotificationCenter.default.addObserver(self, selector: #selector(managedTagsDidChangeNotification(_:)), name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: nil)
            
        } else {
            
            TagListController.setupPersistentStore(withInitialTags: { () -> ([(String, String)]) in
                return [
                    
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
                    
                ]
            }) { [weak self] (_ context: NSManagedObjectContext?, _ error: Error?) in
                
                guard let self = self else { return }
                
                if let context = context {
                    
                    context.undoManager = TagListController.sharedUndoManager
                    TagListController.sharedContext = context
                    NotificationCenter.default.post(name: NSNotification.Name.NSManagedObjectContextDidLoad, object: context)
                    
                    self.setupEmbeddedState(with: context)
                    
                    self.willUndoToken = NotificationCenter.default.observe(name: NSNotification.Name.NSUndoManagerWillUndoChange, object: self.tableView.contextUndoManager, using: { [unowned self] _ in
                        self.setNeedsSaveManagedTags()
                    })
                    self.willRedoToken = NotificationCenter.default.observe(name: NSNotification.Name.NSUndoManagerWillRedoChange, object: self.tableView.contextUndoManager, using: { [unowned self] _ in
                        self.setNeedsSaveManagedTags()
                    })
                    
                    self.didUndoToken = NotificationCenter.default.observe(name: NSNotification.Name.NSUndoManagerDidUndoChange, object: self.tableView.contextUndoManager) { [unowned self] _ in
                        self.internalController.rearrangeObjects()
                    }
                    self.didRedoToken = NotificationCenter.default.observe(name: NSNotification.Name.NSUndoManagerDidRedoChange, object: self.tableView.contextUndoManager) { [unowned self] _ in
                        self.internalController.rearrangeObjects()
                    }
                    
                    NotificationCenter.default.addObserver(self, selector: #selector(self.managedTagsDidChangeNotification(_:)), name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: nil)
                    
                } else if let error = error {
                    
                    self.setupEmbeddedState()
                    self.presentError(error)
                    
                }
                
            }
            
        }
        
    }
    
    private class func setupPersistentStore(withInitialTags: @escaping () -> ([(String, String)]), completionClosure: @escaping (NSManagedObjectContext?, Error?) -> ())
    {
        guard let tagModelURL = Bundle.main.url(forResource: "TagList", withExtension: "momd") else {
            fatalError("error loading model from bundle")
        }
        
        guard let tagModel = NSManagedObjectModel(contentsOf: tagModelURL) else {
            fatalError("error initializing model from \(tagModelURL)")
        }
        
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: tagModel)
        context.persistentStoreCoordinator = coordinator
        
        guard let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last else {
            fatalError("unable to resolve library directory")
        }
        
        let queue = DispatchQueue.global(qos: .background)
        queue.async {
            
            do {
                
                let storeURL = docURL.appendingPathComponent("JSTColorPicker/TagList.sqlite")
                if FileManager.default.fileExists(atPath: storeURL.path) {
                    
                    try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
                    
                } else {
                    
                    try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                    try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
                    
                    var idx = 1
                    withInitialTags().forEach { (tag) in
                        let obj = NSEntityDescription.insertNewObject(forEntityName: "Tag", into: context) as! Tag
                        obj.order = Int64(idx)
                        obj.name = tag.0
                        obj.colorHex = tag.1
                        idx += 1
                    }
                    
                    try context.save()
                    
                }
                
                DispatchQueue.main.sync {
                    completionClosure(context, nil)
                }
                
            } catch {
                
                DispatchQueue.main.sync {
                    completionClosure(nil, error)
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
            
            var idx = lastOrder
            missingNames.forEach { (tagName) in
                let obj = NSEntityDescription.insertNewObject(forEntityName: "Tag", into: context) as! Tag
                obj.order = Int64(idx)
                obj.name = tagName
                obj.colorHex = NSColor.random.sharpCSS
                idx += 1
            }
            
            let addedRowIndexes = IndexSet(integersIn: (lastRowIndex + 1)...(lastRowIndex + idx - lastOrder))
            tableView.insertRows(at: addedRowIndexes)  // make sure that these stubs are inserted
            
            try context.save()
            
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
    
    @objc private func managedTagsDidChangeNotification(_ noti: NSNotification) {
        DispatchQueue.main.async { [weak self] in
            self?.reorderManagedTagsIfNeeded()
            self?.saveManagedTagsIfNeeded()
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
        colorPanel.orderFront(sender)
        
        tableView.selectRowIndexes(
            IndexSet(integer: targetIndex),
            byExtendingSelection: false
        )
    }
    
    @objc internal func colorPanelValueChanged(_ sender: NSColorPanel) {
        
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
        
    }
    
    
    // MARK: - Action
    
    @IBAction func tableViewAction(_ sender: TagListTableView) { }
    
    @IBAction func tableViewDoubleAction(_ sender: TagListTableView) { }
    
    @IBAction func checkedButtonAction(_ sender: NSButton) {
        if sender.allowsMixedState { sender.allowsMixedState = false }
        guard let editDelegate = editDelegate else { return }
        let checkedRow = tableView.row(for: sender)
        editDelegate.editStateChanged(of: arrangedTags[checkedRow].name, to: sender.state)
    }
    
}

extension TagListController: TagListSource {
    
    var arrangedTagController: TagController { internalController }
    var arrangedTags: [Tag] { internalController.arrangedObjects as? [Tag] ?? [] }
    var managedObjectContext: NSManagedObjectContext? { TagListController.sharedContext }
    
    func managedTag(of name: String) -> Tag? {
        
        if arrangedTags.count > 0 {
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
        
        if arrangedTags.count > 0 {
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
    
}

extension TagListController: TagListDragDelegate {
    
    var shouldPerformDragging: Bool { !isEditMode && internalController.isEditable }
    
    func willPerformDragging(_ sender: Any?) -> Bool {
        contentManager?.deselectAllContentItems()
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
        guard !isEditMode, case .idle = tableViewOverlay.state else { return nil }
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
                let editDelegate = editDelegate
            {
                let tagName = arrangedTags[row].name
                cell.state = editDelegate.editState(of: tagName)
            }
            else if col == .columnName {
                cell.isEditable = !isEditMode
            }
            return cell
        }
        return nil
    }
    
}

extension TagListController: NSMenuItemValidation, NSMenuDelegate {
    
    private var hasAttachedSheet: Bool { view.window?.attachedSheet != nil }
    
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

    private func scrollToFirstCheckedRow() {
        if let row = arrangedTags.firstIndex(where: { previewContext?.keys.contains($0.name) ?? false }) {
            tableView.scrollRowToVisible(row)
        }
    }
    
    func previewTags(for items: [ContentItem]) {
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

