//
//  TagListController.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/5/24.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class TagListController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    
    @IBOutlet var managedObjectContext: NSManagedObjectContext!
    @IBOutlet var tagCtrl: TagController!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet var tagMenu: NSMenu!
    
    fileprivate var undoToken: NotificationToken?
    fileprivate var redoToken: NotificationToken?
    
    static public var dragDropType = NSPasteboard.PasteboardType(rawValue: "private.tag.table-row")

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tagCtrl.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        tableView.registerForDraggedTypes([TagListController.dragDropType])
        
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
                self?.presentError(error)
                return
            }
            self?.managedObjectContext.undoManager = self?.undoManager
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
        //removeTagBtnTapped(sender)
        // TODO: delete tags
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
    
    
    // MARK: - Drag/Drop
    
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard let collection = tagCtrl.arrangedObjects as? [Tag] else { return nil }
        let item = NSPasteboardItem()
        item.setPropertyList([
            "row": row,
            "name": collection[row].name ?? ""
        ], forType: TagListController.dragDropType)
        return item
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        guard tagCtrl.filterPredicate == nil else { return [] }
        if dropOperation == .above {
            return .move
        }
        return []
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard var collection = tagCtrl.arrangedObjects as? [Tag] else { return false }
        
        var oldIndexes = [Int]()
        info.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:]) { dragItem, _, _ in
            if let obj = (dragItem.item as! NSPasteboardItem).propertyList(forType: TagListController.dragDropType) as? [String: Any],
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
