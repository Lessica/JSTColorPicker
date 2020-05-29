//
//  TagListController.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/5/24.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class TagListController: NSViewController {
    
    @IBOutlet var managedObjectContext: NSManagedObjectContext!
    @IBOutlet var tagCtrl: TagController!
    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet weak var tableView: TagListTableView!
    @IBOutlet weak var tableViewOverlay: TagListOverlayView!
    @IBOutlet var tagMenu: NSMenu!
    
    public weak var sceneToolDataSource: SceneToolDataSource? {
        get { return tableViewOverlay.sceneToolDataSource }
        set { tableViewOverlay.sceneToolDataSource = newValue }
    }
    
    fileprivate var undoToken: NotificationToken?
    fileprivate var redoToken: NotificationToken?
    
    static public var attachPasteboardType = NSPasteboard.PasteboardType(rawValue: "private.jst.tag.attach")
    static fileprivate var inlinePasteboardType = NSPasteboard.PasteboardType(rawValue: "private.jst.tag.inline")
    
    fileprivate var colorPanel: NSColorPanel {
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.isContinuous = false
        return panel
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableViewOverlay.dataSource = self
        tableViewOverlay.dragDelegate = self
        
        tagCtrl.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        tableView.registerForDraggedTypes([TagListController.inlinePasteboardType])
        
        undoToken = NotificationCenter.default.observe(name: NSNotification.Name.NSUndoManagerDidUndoChange, object: undoManager) { [unowned self] (notification) in
            self.tagCtrl.rearrangeObjects()
        }
        redoToken = NotificationCenter.default.observe(name: NSNotification.Name.NSUndoManagerDidRedoChange, object: undoManager) { [unowned self] (notification) in
            self.tagCtrl.rearrangeObjects()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(mocDidChangeNotification(_:)), name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: nil)
        
        setupPersistentStore(fetchInitialTags: { () -> ([(String, String)]) in
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
                
                /* Status */
                ("Disabled",       "#657899"),
                ("Active",         "#1C314E"),
                
            ]
        }) { [weak self] (_ error: Error?) in
            if let error = error {
                self?.tagCtrl.isEditable = false
                self?.presentError(error)
                return
            }
            self?.managedObjectContext.undoManager = self?.undoManager
            self?.tagCtrl.isEditable = true
            self?.tagCtrl.rearrangeObjects()
        }
        
    }
    
    fileprivate func setupPersistentStore(fetchInitialTags: @escaping () -> ([(String, String)]), completionClosure: @escaping (Error?) -> ()) {
        guard let tagModelURL = Bundle.main.url(forResource: "TagList", withExtension: "momd") else {
            fatalError("error loading model from bundle")
        }
        
        guard let tagModel = NSManagedObjectModel(contentsOf: tagModelURL) else {
            fatalError("error initializing model from \(tagModelURL)")
        }
        
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: tagModel)
        managedObjectContext.persistentStoreCoordinator = coordinator
        
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
                        fetchInitialTags().forEach { (tag) in
                            let obj = NSEntityDescription.insertNewObject(forEntityName: "Tag", into: self.managedObjectContext) as! Tag
                            obj.order = Int64(idx)
                            obj.name = tag.0
                            obj.colorHex = tag.1
                            idx += 1
                        }
                        
                        do {
                            try self.managedObjectContext.save()
                        } catch {
                            DispatchQueue.main.sync {
                                completionClosure(error)
                            }
                        }
                        
                    }
                    
                }
                
                DispatchQueue.main.sync {
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
        guard let collection = managedTags else { return }
        let rows = ((tableView.clickedRow >= 0 && !tableView.selectedRowIndexes.contains(tableView.clickedRow)) ? IndexSet(integer: tableView.clickedRow) : IndexSet(tableView.selectedRowIndexes))
            .filteredIndexSet(includeInteger: { $0 < collection.count })
        tagCtrl.remove(contentsOf: rows.map({ collection[$0] }))
    }
    
    @IBAction private func insertTagBtnTapped(_ sender: Any) {
        tagCtrl.insert(sender)
        setNeedsRearrangeMOC()
        setNeedsSaveMOC()
    }
    
    @IBAction private func removeTagBtnTapped(_ sender: Any) {
        tagCtrl.remove(sender)
        setNeedsSaveMOC()
    }
    
    @IBAction private func tagFieldValueChanged(_ sender: NSTextField) {
        setNeedsSaveMOC()
    }
    
    @objc private func mocDidChangeNotification(_ noti: NSNotification) {
        guard let moc = noti.object as? NSManagedObjectContext else { return }
        guard moc == managedObjectContext else { return }
        rearrangeMOCIfNeeded()
        saveMOCIfNeeded()
    }
    
    fileprivate var shouldRearrangeMOC: Bool = false
    fileprivate var shouldSaveMOC: Bool = false
    
    fileprivate func setNeedsRearrangeMOC() {
        shouldRearrangeMOC = true
    }
    
    fileprivate func setNeedsSaveMOC() {
        shouldSaveMOC = true
    }
    
    fileprivate func saveMOCIfNeeded() {
        guard shouldSaveMOC else { return }
        shouldSaveMOC = false
        guard managedObjectContext.hasChanges else { return }
        do {
            try managedObjectContext.save()
        } catch let error as NSError {
            if error.code == 133021, let itemName = ((managedObjectContext.insertedObjects.first ?? managedObjectContext.updatedObjects.first) as? Tag)?.name {
                presentError(ContentError.itemExists(item: itemName))
            } else {
                presentError(error)
            }
            managedObjectContext.rollback()
        } catch {
            presentError(error)
            managedObjectContext.rollback()
        }
    }
    
    fileprivate func rearrangeMOCIfNeeded() {
        guard shouldRearrangeMOC else { return }
        shouldRearrangeMOC = false
        guard let items = tagCtrl.arrangedObjects as? [Tag] else { return }
        reorderTags(items)
    }
    
    fileprivate func reorderTags(_ items: [Tag]) {
        var itemIdx: Int64 = 0
        items.forEach({
            $0.order = itemIdx
            itemIdx += 1
        })
    }
    
    
    // MARK: - Menu
    
    fileprivate weak var menuTargetObject: Tag?
    
    @IBAction private func changeColorItemTapped(_ sender: NSMenuItem) {
        guard let collection = managedTags else { return }
        guard let targetIndex = (tableView.clickedRow >= 0 && !tableView.selectedRowIndexes.contains(tableView.clickedRow)) ? tableView.clickedRow : tableView.selectedRowIndexes.first else { return }
        guard let css = collection[targetIndex].colorHex, let color = NSColor(css: css, alpha: 1.0) else { return }
        
        menuTargetObject = collection[targetIndex]
        
        colorPanel.setTarget(nil)
        colorPanel.setAction(nil)
        colorPanel.color = color
        
        colorPanel.setTarget(self)
        colorPanel.setAction(#selector(colorPanelValueChanged(_:)))
        colorPanel.orderFront(sender)
    }
    
    @objc private func colorPanelValueChanged(_ sender: NSColorPanel) {
        guard let tag = menuTargetObject, tag.managedObjectContext != nil else { return }
        tag.colorHex = sender.color.sharpCSS
        setNeedsSaveMOC()
    }
    
}

extension TagListController: TagListDataSource {
    
    var managedTags: [Tag]? {
        return tagCtrl.arrangedObjects as? [Tag]
    }
    
    func managedTag(of name: String) -> Tag? {
        return managedTags?.first(where: { $0.name == name })
    }
    
    func managedTags(of names: [String]) -> [Tag] {
        return managedTags?.filter({ (tag) -> Bool in
            if let tagName = tag.name {
                return names.contains(tagName)
            }
            return false
        }) ?? []
    }
    
}

extension TagListController: TagListDragDelegate {
    
    var canPerformDrag: Bool {
        return tagCtrl.isEditable
    }
    
    var selectedRowIndexes: IndexSet { tableView.selectedRowIndexes }
    
    func selectedRowIndexes(at point: CGPoint, shouldHighlight: Bool) -> IndexSet {
        var indexes = tableView.selectedRowIndexes
        let rowAtPoint = tableView.row(at: scrollView.convert(point, to: tableView))
        if rowAtPoint > 0 {
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
        return rowIndexes.map({ scrollView.convert(tableView.rect(ofRow: $0), from: tableView) })
    }
    
}

extension TagListController: NSTableViewDelegate, NSTableViewDataSource {
    
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard case .idle = tableViewOverlay.state else { return nil }
        guard let collection = managedTags else { return nil }
        let item = NSPasteboardItem()
        item.setPropertyList([
            "row": row,
            "name": collection[row].name ?? ""
        ], forType: TagListController.inlinePasteboardType)
        return item
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        guard case .idle = tableViewOverlay.state else { return [] }
        guard tagCtrl.filterPredicate == nil else { return [] }
        if dropOperation == .above {
            return .move
        }
        return []
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard case .idle = tableViewOverlay.state else { return false }
        guard var collection = managedTags else { return false }
        
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
        tagCtrl.content = NSMutableArray(array: collection)
        
        setNeedsSaveMOC()
        return true
    }
    
}

extension TagListController: NSUserInterfaceValidations {
    
    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(changeColorItemTapped(_:)) {
            guard tableView.clickedRow >= 0 else { return false }
            if tableView.selectedRowIndexes.count > 1 && tableView.selectedRowIndexes.contains(tableView.clickedRow) { return false }
            return true
        }
        else if item.action == #selector(delete(_:)) {
            return tableView.clickedRow >= 0 || tableView.selectedRowIndexes.count > 0
        }
        return false
    }
    
}

extension TagListController: NSMenuDelegate {
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu == tagMenu {
            
        }
    }
    
}

