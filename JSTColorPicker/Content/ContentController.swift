//
//  ContentController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/21/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa
import ShortcutGuide

extension NSUserInterfaceItemIdentifier {
    
    static let toggleTableColumnIdentifier  = NSUserInterfaceItemIdentifier("toggle-id")
    static let toggleTableColumnSimilarity  = NSUserInterfaceItemIdentifier("toggle-similarity")
    static let toggleTableColumnTag         = NSUserInterfaceItemIdentifier("toggle-tag")
    static let toggleTableColumnDescription = NSUserInterfaceItemIdentifier("toggle-desc")
    
    static let columnIdentifier  = NSUserInterfaceItemIdentifier("col-id")
    static let columnSimilarity  = NSUserInterfaceItemIdentifier("col-similarity")
    static let columnTag         = NSUserInterfaceItemIdentifier("col-tag")
    static let columnDescription = NSUserInterfaceItemIdentifier("col-desc")
    
    static let removeTags        = NSUserInterfaceItemIdentifier("remove-tags")
    
}

protocol ContentActionDelegate: class {
    func contentActionAdded(_ items: [ContentItem])
    func contentActionSelected(_ items: [ContentItem])
    func contentActionConfirmed(_ items: [ContentItem])
    func contentActionUpdated(_ items: [ContentItem])
    func contentActionDeleted(_ items: [ContentItem])
}

extension NSViewController {
    
    var firstResponder: NSResponder? {
        guard let window = view.window else { return nil }
        return window.firstResponder
    }
    
    @discardableResult
    func makeFirstResponder(_ responder: NSResponder?) -> Bool {
        guard let window = view.window else { return false }
        return window.makeFirstResponder(responder)
    }
    
}

class ContentController: NSViewController {
    
    public weak var actionManager   : ContentActionDelegate!
    public weak var tagManager      : TagListSource!
    
    internal weak var screenshot    : Screenshot?
    private var documentContent     : Content?         { screenshot?.content }
    private var documentImage       : PixelImage?      { screenshot?.image   }
    private var documentExport      : ExportManager?   { screenshot?.export  }
    private var documentState       : Screenshot.State { screenshot?.state ?? .notLoaded }
    override var undoManager        : UndoManager!     { screenshot?.undoManager }
    
    private var nextID: Int {
        if let lastID = documentContent?.items.last?.id {
            return lastID + 1
        }
        return 1
    }
    private var nextSimilarity: Double {
        if let lastSimilarity = documentContent?.items.last?.similarity {
            return lastSimilarity
        }
        return UserDefaults.standard[.initialSimilarity]
    }
    
    private var undoToken                 : NotificationToken?
    private var redoToken                 : NotificationToken?
    private var delayedRowIndexes         : IndexSet?
    
    @IBOutlet var tableMenuDelegateProxy  : NSMenuDelegateProxy!
    
    @IBOutlet var tableMenu               : NSMenu!
    @IBOutlet var tableHeaderMenu         : NSMenu!
    @IBOutlet var tableRemoveTagsMenu     : NSMenu!
    @IBOutlet var tableRemoveTagsMenuItem : NSMenuItem!
    
    @IBOutlet var itemNewMenu             : NSMenu!
    @IBOutlet var itemNewColorMenuItem    : NSMenuItem!
    @IBOutlet var itemNewAreaMenuItem     : NSMenuItem!
    
    @IBOutlet var itemReprMenu            : NSMenu!
    @IBOutlet var itemReprColorMenuItem   : NSMenuItem!
    @IBOutlet var itemReprAreaMenuItem    : NSMenuItem!
    @IBOutlet var itemReprAreaAltMenuItem : NSMenuItem!
    
    @IBOutlet weak var tableView          : ContentTableView!
    @IBOutlet weak var clipView           : ContentClipView!
    @IBOutlet weak var scrollView         : ContentScrollView!
    @IBOutlet weak var columnIdentifier   : NSTableColumn!
    @IBOutlet weak var columnSimilarity   : NSTableColumn!
    @IBOutlet weak var columnTag          : NSTableColumn!
    @IBOutlet weak var columnDescription  : NSTableColumn!
    private var usesDetailedToolTips: Bool = false
    
    @IBOutlet weak var addCoordinateButton: NSButton!
    @IBOutlet weak var addCoordinateField : NSTextField!
    
    private var selectedRowIndex: Int? {
        (tableView.clickedRow >= 0 && !tableView.selectedRowIndexes.contains(tableView.clickedRow)) ? tableView.clickedRow : tableView.selectedRowIndexes.first
    }
    
    private var selectedRowIndexes: IndexSet {
        (tableView.clickedRow >= 0 && !tableView.selectedRowIndexes.contains(tableView.clickedRow))
            ? IndexSet(integer: tableView.clickedRow)
            : IndexSet(tableView.selectedRowIndexes)
    }
    
    private var selectedContentItems: [ContentItem]? {
        guard let collection = documentContent?.items else { return nil }
        return selectedRowIndexes.map { collection[$0] }
    }
    
    private var preparedSelectedItemCount    : Int?
    private var preparedMenuTags             : OrderedSet<String>?
    private var preparedMenuTagsAndCounts    : [String: Int]?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        addCoordinateButton.isEnabled = false
        addCoordinateField.isEnabled = false
        
        tableView.tableViewResponder = self
        tableView.registerForDraggedTypes([.color, .area])
        
        NotificationCenter.default.addObserver(self, selector: #selector(applyPreferences(_:)), name: UserDefaults.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(managedTagsDidLoadNotification(_:)), name: NSNotification.Name.NSManagedObjectContextDidLoad, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(managedTagsDidChangeNotification(_:)), name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: nil)
        
        applyPreferences(nil)
        invalidateRestorableState()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        DispatchQueue.main.async { [weak self] in
            self?.tableView.scroll(.zero)
        }
    }
    
    @objc private func applyPreferences(_ notification: Notification?) {
        updateColumns()
        
        if notification == nil {
            usesDetailedToolTips = UserDefaults.standard[.usesDetailedToolTips]
        } else {
            let toValue: Bool = UserDefaults.standard[.usesDetailedToolTips]
            if usesDetailedToolTips != toValue {
                usesDetailedToolTips = toValue
                tableView.reloadData()
            }
        }
    }
    
    override func willPresentError(_ error: Error) -> Error {
        let error = super.willPresentError(error)
        debugPrint(error.localizedDescription)
        return error
    }
    
    @IBAction func resetColumns(_ sender: NSMenuItem) {
        UserDefaults.standard.removeObject(forKey: .toggleTableColumnIdentifier)
        UserDefaults.standard.removeObject(forKey: .toggleTableColumnSimilarity)
        UserDefaults.standard.removeObject(forKey: .toggleTableColumnTag)
        UserDefaults.standard.removeObject(forKey: .toggleTableColumnDescription)
        
        tableView.tableColumns.forEach({ tableView.removeTableColumn($0) })
        let tableCols: [NSTableColumn] = [
            columnIdentifier,
            columnSimilarity,
            columnTag,
            columnDescription
        ]
        tableCols.forEach({ tableView.addTableColumn($0) })
        tableCols.forEach({ $0.width = $0.minWidth })
        
        updateColumns()
    }
    
    @IBAction func similarityFieldChanged(_ sender: NSTextField) {
        guard let content = documentContent else { return }
        
        let row = tableView.row(for: sender)
        assert(row >= 0 && row < content.items.count)
        
        let origItem = content.items[row]
        let value = sender.doubleValue, origValue = origItem.similarity * 100.0
        if value >= 1 && value <= 100 && abs(value - origValue) >= 0.99 {
            
            let targetSimilarity = min(max(value / 100.0, 0.01), 1.0)
            let replItem = origItem.copy() as! ContentItem
            replItem.similarity = targetSimilarity
            UserDefaults.standard[.initialSimilarity] = targetSimilarity
            
            let itemIndexes = internalUpdateContentItems([replItem])
            let col = tableView.column(withIdentifier: .columnSimilarity)
            tableView.reloadData(forRowIndexes: itemIndexes, columnIndexes: col >= 0 ? IndexSet(integer: col) : IndexSet())
            
            return
            
        }
        
        let similarity = String(Int(origItem.similarity * 100.0))
        sender.stringValue = similarity + "%"
    }
    
    @IBAction func addCoordinateFieldChanged(_ sender: NSTextField) {
        guard let image = documentImage else { return }
        
        do {
            
            let inputVal = sender.stringValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            guard !inputVal.isEmpty else { return }
            
            let scanner = Scanner(string: inputVal)
            scanner.charactersToBeSkipped = CharacterSet.alphanumerics.inverted
            
            var x = Int.max
            var y = Int.max
            let scanned1 = scanner.scanInt(&x)
            let scanned2 = scanner.scanInt(&y)
            
            guard scanned1 && scanned2 else {
                throw Content.Error.itemNotValid(item: inputVal)
            }
            
            var x2 = Int.max
            var y2 = Int.max
            let scanned3 = scanner.scanInt(&x2)
            let scanned4 = scanner.scanInt(&y2)
            
            var addedOrSelected = false
            
            // color & coordinate
            if !scanned3 || !scanned4 {
                
                let coordinate = PixelCoordinate(x: x, y: y)
                
                guard image.bounds.contains(coordinate) else {
                    throw Content.Error.itemOutOfRange(item: coordinate, range: image.size)
                }
                
                do {
                    _ = try addContentItem(of: coordinate)
                } catch Content.Error.itemExists {
                    try selectContentItem(of: coordinate)
                }
                
                sender.stringValue = ""
                addedOrSelected = true
                
            }
            else {
                
                let useAlt: Bool = UserDefaults.standard[.usesAlternativeAreaRepresentation]
                
                var rect: PixelRect!
                if !useAlt {
                    rect = PixelRect(coordinate1: PixelCoordinate(x: x, y: y), coordinate2: PixelCoordinate(x: x2, y: y2))
                }
                else {
                    rect = PixelRect(origin: PixelCoordinate(x: x, y: y), size: PixelSize(width: x2, height: y2))
                }
                
                guard image.bounds.contains(rect) else {
                    throw Content.Error.itemOutOfRange(item: rect, range: image.bounds)
                }
                
                do {
                    _ = try addContentItem(of: rect)
                } catch Content.Error.itemExists {
                    try selectContentItem(of: rect)
                }
                
                sender.stringValue = ""
                addedOrSelected = true
                
            }
            
            if !addedOrSelected {
                throw Content.Error.itemNotValid(item: inputVal)
            }
            
        } catch {
            presentError(error)
            makeFirstResponder(sender)
        }
        
    }
    
    @IBAction func addCoordinateAction(_ sender: NSButton) {
        if addCoordinateField.stringValue.isEmpty {
            guard let event = view.window?.currentEvent else { return }
            NSMenu.popUpContextMenu(itemNewMenu, with: event, for: sender)
        } else {
            addCoordinateFieldChanged(addCoordinateField)
        }
    }
    
    deinit {
        debugPrint("\(className):\(#function)")
    }
    
}

extension ContentController {
    
    @discardableResult
    private func internalAddContentItems(_ items: [ContentItem], isRegistered registered: Bool = false) -> IndexSet {
        guard let content = documentContent else { return IndexSet() }
        undoManager.registerUndo(withTarget: self, handler: { $0.internalDeleteContentItems(items, isRegistered: true) })
        if !registered {
            undoManager.setActionName(NSLocalizedString("Add Items", comment: "internalAddContentItems(_:)"))
        }
        actionManager.contentActionAdded(items)
        var indexes = IndexSet()
        items.sorted(by: { $0.id < $1.id }).forEach { (item) in
            let idx = content.items.insertionIndexOf(item, isOrderedBefore: { $0.id < $1.id })
            content.items.insert(item, at: idx)
            indexes.insert(idx)
        }
        return indexes
    }
    
    @discardableResult
    private func internalDeleteContentItems(_ items: [ContentItem], isRegistered registered: Bool = false) -> IndexSet {
        guard let content = documentContent else { return IndexSet() }
        let itemIDs = Set(items.compactMap({ $0.id }))
        let itemsToRemove = content.items.filter({ itemIDs.contains($0.id) })
        undoManager.registerUndo(withTarget: self, handler: { (target) in
            target.delayedRowIndexes = target.internalAddContentItems(itemsToRemove, isRegistered: true)
        })
        if !registered {
            undoManager.setActionName(NSLocalizedString("Delete Items", comment: "internalDeleteContentItems(_:)"))
        }
        actionManager.contentActionDeleted(items)
        let indexes = content.items
            .enumerated()
            .filter({ itemIDs.contains($1.id) })
            .reduce(into: IndexSet()) { $0.insert($1.offset) }
        content.items.remove(at: indexes)
        return indexes
    }
    
    @discardableResult
    private func internalUpdateContentItems(_ items: [ContentItem], isRegistered registered: Bool = false) -> IndexSet {
        guard let content = documentContent else { return IndexSet() }
        let itemIDs = Set(items.compactMap({ $0.id }))
        let itemsToUpdate = content.items.filter({ itemIDs.contains($0.id) })
        undoManager.registerUndo(withTarget: self, handler: { $0.internalUpdateContentItems(itemsToUpdate, isRegistered: true) })
        if !registered {
            undoManager.setActionName(NSLocalizedString("Update Items", comment: "internalUpdateContentItems(_:)"))
        }
        actionManager.contentActionUpdated(items)
        content.items.removeAll(where: { itemIDs.contains($0.id) })
        var indexes = IndexSet()
        items.sorted(by: { $0.id < $1.id }).forEach { (item) in
            let idx = content.items.insertionIndexOf(item, isOrderedBefore: { $0.id < $1.id })
            content.items.insert(item, at: idx)
            indexes.insert(idx)
        }
        return indexes
    }
    
    private func internalSelectContentItems(
        in set: IndexSet?,
        byExtendingSelection extend: Bool,
        byFocusingSelection focus: Bool = true
    ) {
        if let set = set, !set.isEmpty, let lastIndex = set.last {
            if tableView.selectedRowIndexes != set {
                tableView.selectRowIndexes(set, byExtendingSelection: extend)
            } else {
                internalTableViewSelectionDidChange(nil)
            }
            if focus {
                tableView.scrollRowToVisible(lastIndex)
                makeFirstResponder(tableView)
            }
        }
        else {
            if !extend {
                if !tableView.selectedRowIndexes.isEmpty {
                    tableView.deselectAll(nil)
                } else {
                    internalTableViewSelectionDidChange(nil)
                }
            }
        }
    }
    
}

extension ContentController: ContentItemSource {
    
    func contentItem(of coordinate: PixelCoordinate) throws -> ContentItem {
        guard let image = documentImage else { throw Content.Error.notLoaded }
        guard let color = image.color(at: coordinate) else { throw Content.Error.itemOutOfRange(item: coordinate, range: image.size) }
        return color
    }
    
    func contentItem(of rect: PixelRect) throws -> ContentItem {
        guard let image = documentImage else { throw Content.Error.notLoaded }
        guard rect.hasStandardized && rect.size > PixelSize(width: 1, height: 1) else { throw Content.Error.itemNotValid(item: rect) }
        guard let area = image.area(at: rect) else { throw Content.Error.itemOutOfRange(item: rect, range: image.size) }
        return area
    }
    
}

extension ContentController: ContentDelegate {
    
    func addContentItem(of coordinate: PixelCoordinate) throws -> ContentItem? {
        return try addContentItem(contentItem(of: coordinate))
    }
    
    func addContentItem(of rect: PixelRect) throws -> ContentItem? {
        return try addContentItem(contentItem(of: rect))
    }
    
    @discardableResult
    private func addContentItem(_ item: ContentItem) throws -> ContentItem? {
        
        guard let content = documentContent  else { throw Content.Error.notLoaded }
        guard documentState.isWriteable      else { throw Content.Error.notWritable   }
        
        let maximumItemCountEnabled: Bool = UserDefaults.standard[.maximumItemCountEnabled]
        if maximumItemCountEnabled {
            let maximumItemCount: Int = UserDefaults.standard[.maximumItemCount]
            guard content.items.count < maximumItemCount else { throw Content.Error.itemReachLimit(totalSpace: maximumItemCount) }
        }
        guard content.items.last(where: { $0 == item }) == nil else { throw Content.Error.itemExists(item: item) }
        
        item.id = nextID
        item.similarity = nextSimilarity
        
        let itemIndexes = internalAddContentItems([item])
        tableView.reloadData()
        
        internalSelectContentItems(in: itemIndexes, byExtendingSelection: false)
        return item
        
    }
    
    @discardableResult
    private func importContentItems(_ items: [ContentItem]) throws -> [ContentItem] {
        
        guard let content = documentContent,
            let image = documentImage    else { throw Content.Error.notLoaded }
        guard documentState.isWriteable  else { throw Content.Error.notWritable   }
        
        let maximumItemCountEnabled: Bool = UserDefaults.standard[.maximumItemCountEnabled]
        if maximumItemCountEnabled {
            let maximumItemCount: Int = UserDefaults.standard[.maximumItemCount]
            let totalSpace = content.items.count + items.count
            guard totalSpace <= maximumItemCount else { throw Content.Error.itemReachLimitBatch(moreSpace: totalSpace - maximumItemCount) }
        }
        
        let existingCoordinates = Set(content.items.compactMap({ ($0 as? PixelColor)?.coordinate }))
        let existingRects = Set(content.items.compactMap({ ($0 as? PixelArea)?.rect }))
        let beginRows = tableView.numberOfRows
        var beginID = nextID
        
        var relatedItems: [ContentItem] = []
        for item in items {
            var relatedItem: ContentItem?
            if let color = item as? PixelColor {
                let coordinate = color.coordinate
                guard !existingCoordinates.contains(coordinate) else { throw Content.Error.itemExists(item: color) }
                guard let newItem = image.color(at: coordinate) else { throw Content.Error.itemOutOfRange(item: coordinate, range: image.size)}
                newItem.copyFrom(color)
                relatedItem = newItem
            }
            else if let area = item as? PixelArea {
                let rect = area.rect
                guard !existingRects.contains(rect) else { throw Content.Error.itemExists(item: area) }
                guard let newItem = image.area(at: rect) else { throw Content.Error.itemOutOfRange(item: rect, range: image.size) }
                newItem.copyFrom(area)
                relatedItem = newItem
            }
            if let relatedItem = relatedItem {
                relatedItem.id = beginID
                relatedItems.append(relatedItem)
                beginID += 1
            }
        }
        
        internalAddContentItems(relatedItems)
        tableView.reloadData()
        
        internalSelectContentItems(in: IndexSet(integersIn: beginRows..<beginRows + relatedItems.count), byExtendingSelection: false)
        return relatedItems
        
    }
    
    @discardableResult
    private func selectContentItem(of coordinate: PixelCoordinate) throws -> ContentItem? {
        guard let image = documentImage               else { throw Content.Error.notLoaded }
        guard let color = image.color(at: coordinate) else { throw Content.Error.itemOutOfRange(item: coordinate, range: image.size) }
        return try selectContentItem(color, byExtendingSelection: false)
    }
    
    @discardableResult
    private func selectContentItem(of rect: PixelRect) throws -> ContentItem? {
        guard let image = documentImage       else { throw Content.Error.notLoaded }
        guard let area = image.area(at: rect) else { throw Content.Error.itemOutOfRange(item: rect, range: image.size) }
        return try selectContentItem(area, byExtendingSelection: false)
    }
    
    func selectContentItem(_ item: ContentItem, byExtendingSelection extend: Bool) throws -> ContentItem? {
        guard let content = documentContent                      else { throw Content.Error.notLoaded }
        guard let itemIndex = content.items.firstIndex(of: item) else { throw Content.Error.itemDoesNotExist(item: item) }
        internalSelectContentItems(in: IndexSet(integer: itemIndex), byExtendingSelection: extend)
        return item
    }
    
    func selectContentItems(_ items: [ContentItem], byExtendingSelection extend: Bool) throws -> [ContentItem]? {
        guard let content = documentContent else { throw Content.Error.notLoaded }
        let itemIndexes = IndexSet(
            items.compactMap({ content.items.firstIndex(of: $0) })
        )
        guard itemIndexes.count == items.count else { throw Content.Error.itemDoesNotExistPartial  }
        internalSelectContentItems(in: itemIndexes, byExtendingSelection: extend)
        return items
    }
    
    func deselectContentItem(_ item: ContentItem) throws -> ContentItem? {
        guard let content = documentContent                      else { throw Content.Error.notLoaded }
        guard let itemIndex = content.items.firstIndex(of: item) else { throw Content.Error.itemDoesNotExist(item: item) }
        tableView.deselectRow(itemIndex)
        makeFirstResponder(tableView)
        return item
    }
    
    func deselectAllContentItems() {
        tableView.deselectAll(nil)
    }
    
    func deleteContentItem(of coordinate: PixelCoordinate, byIgnoringPopups ignore: Bool) throws -> ContentItem? {
        guard let content = documentContent  else { throw Content.Error.notLoaded }
        guard documentState.isWriteable      else { throw Content.Error.notWritable }
        
        guard let item = content.lazyColors.last(where: { $0.coordinate == coordinate })
            ?? content.lazyAreas.last(where: { $0.rect.contains(coordinate) })
            else { throw Content.Error.itemDoesNotExist(item: coordinate) }
        return try deleteContentItem(item, bySkipingValidation: true, byIgnoringPopups: ignore)
    }
    
    func deleteContentItem(_ item: ContentItem, byIgnoringPopups ignore: Bool) throws -> ContentItem? {
        return try deleteContentItem(item, bySkipingValidation: false, byIgnoringPopups: ignore)
    }
    
    private func deleteContentItem(_ item: ContentItem, bySkipingValidation skip: Bool, byIgnoringPopups ignore: Bool) throws -> ContentItem? {
        if !skip {
            guard let content = documentContent  else { throw Content.Error.notLoaded }
            guard documentState.isWriteable      else { throw Content.Error.notWritable   }
            guard content.items.firstIndex(of: item) != nil else { throw Content.Error.itemDoesNotExist(item: item) }
        }
        guard deleteConfirmForItems([item]) else { throw Content.Error.userAborted }
        
        let itemIndexes = internalDeleteContentItems([item])
        tableView.removeRows(at: itemIndexes, withAnimation: .effectFade)
        return item
    }
    
    func updateContentItem(_ item: ContentItem, to coordinate: PixelCoordinate) throws -> ContentItem? {
        guard let content = documentContent,
            let image = documentImage    else { throw Content.Error.notLoaded }
        guard documentState.isWriteable  else { throw Content.Error.notWritable   }
        
        guard content.items.first(where: { $0.id == item.id }) != nil                           else { throw Content.Error.itemDoesNotExist(item: item) }
        if let conflictItem = content.lazyColors.first(where: { $0.coordinate == coordinate })       { throw Content.Error.itemConflict(item1: coordinate, item2: conflictItem) }
        guard let replItem = image.color(at: coordinate)                                        else { throw Content.Error.itemOutOfRange(item: coordinate, range: image.size) }
        
        replItem.copyFrom(item)
        
        let itemIndexes = internalUpdateContentItems([replItem])
        let col = tableView.column(withIdentifier: .columnDescription)
        tableView.reloadData(forRowIndexes: itemIndexes, columnIndexes: col >= 0 ? IndexSet(integer: col) : IndexSet())
        
        internalSelectContentItems(in: itemIndexes, byExtendingSelection: false)
        return replItem
    }
    
    func updateContentItem(_ item: ContentItem, to rect: PixelRect) throws -> ContentItem? {
        guard let content = documentContent,
            let image = documentImage    else { throw Content.Error.notLoaded }
        guard documentState.isWriteable  else { throw Content.Error.notWritable   }
        
        guard content.items.first(where: { $0.id == item.id }) != nil             else { throw Content.Error.itemDoesNotExist(item: item) }
        if let conflictItem = content.lazyAreas.first(where: { $0.rect == rect })      { throw Content.Error.itemConflict(item1: rect, item2: conflictItem) }
        guard let replItem = image.area(at: rect)                                 else { throw Content.Error.itemOutOfRange(item: rect, range: image.size) }
        
        replItem.copyFrom(item)
        
        let itemIndexes = internalUpdateContentItems([replItem])
        let col = tableView.column(withIdentifier: .columnDescription)
        tableView.reloadData(forRowIndexes: itemIndexes, columnIndexes: col >= 0 ? IndexSet(integer: col) : IndexSet())
        
        internalSelectContentItems(in: itemIndexes, byExtendingSelection: false)
        return replItem
    }
    
    func updateContentItem(_ item: ContentItem) throws -> ContentItem? {
        guard let content = documentContent  else { throw Content.Error.notLoaded }
        guard documentState.isWriteable      else { throw Content.Error.notWritable   }
        
        guard content.items.first(where: { $0.id == item.id }) != nil              else { throw Content.Error.itemDoesNotExist(item: item) }
        
        let replItem = item.copy() as! ContentItem
        let replItemIndexes = internalUpdateContentItems([replItem])
        tableView.reloadData(forRowIndexes: replItemIndexes, columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns))
        
        internalSelectContentItems(in: replItemIndexes, byExtendingSelection: false)
        return replItem
    }
    
    func updateContentItems(_ items: [ContentItem]) throws -> [ContentItem]? {
        guard let content = documentContent  else { throw Content.Error.notLoaded }
        guard documentState.isWriteable      else { throw Content.Error.notWritable   }
        
        let itemIndexes = IndexSet(
            items.compactMap({ content.items.firstIndex(of: $0) })
        )
        guard itemIndexes.count == items.count else { throw Content.Error.itemDoesNotExistPartial  }
        
        let replItems = items.map({ $0.copy() as! ContentItem })
        let replItemIndexes = internalUpdateContentItems(replItems)
        tableView.reloadData(forRowIndexes: replItemIndexes, columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns))
        
        internalSelectContentItems(in: replItemIndexes, byExtendingSelection: false)
        return replItems
    }
    
}

extension ContentController: ContentTableViewResponder {
    @IBAction func tableViewAction(_ sender: ContentTableView) {
        // replaced by -tableViewSelectionDidChange(_:)
    }
    
    @IBAction func tableViewDoubleAction(_ sender: ContentTableView) {
        let optionPressed = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.option)
        if !optionPressed {
            locate(sender)
        } else {
            relocate(sender)
        }
    }
}

extension ContentController {

    private static let restorableTableViewSelectedState = "tableView.selectedRowIndexes"

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        coder.encode(NSIndexSet(indexSet: tableView.selectedRowIndexes), forKey: ContentController.restorableTableViewSelectedState)
    }

    override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)
        if let indexSet = coder.decodeObject(of: NSIndexSet.self, forKey: ContentController.restorableTableViewSelectedState)?
            .indexes(passingTest: { _,_ in true })
        {
            internalSelectContentItems(
                in: indexSet,
                byExtendingSelection: false,
                byFocusingSelection: false
            )
        }
    }

}

extension ContentController: NSMenuItemValidation, NSMenuDelegate {
    
    private var hasAttachedSheet: Bool { view.window?.attachedSheet != nil }
    
    func menuWillOpen(_ menu: NSMenu) {
        // menu item without action
        if menu == tableMenu {
            if documentState.isLoaded {
                tableRemoveTagsMenuItem.isEnabled = tableView.clickedRow >= 0 || tableView.selectedRowIndexes.count > 0
            } else {
                tableRemoveTagsMenuItem.isEnabled = false
            }
        }
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        
        guard !hasAttachedSheet else { return false }
        
        // menu item with action
        if menuItem.action == #selector(copy(_:))
            || menuItem.action == #selector(exportAs(_:))
            || menuItem.action == #selector(tags(_:))
            || menuItem.action == #selector(delete(_:))
        {  // contents available / multiple targets / from both menu
            
            if menuItem.action == #selector(tags(_:))
                || menuItem.action == #selector(delete(_:))
            {
                guard documentState.isWriteable else { return false }
            }
            
            guard documentState.isLoaded else { return false }
            return tableView.clickedRow >= 0 || tableView.selectedRowIndexes.count > 0
            
        }
            
        else if menuItem.action == #selector(locate(_:))
            || menuItem.action == #selector(relocate(_:))
        {  // contents available / single target / from right click menu
            
            if menuItem.action == #selector(relocate(_:)) {
                guard documentState.isWriteable else { return false }
            }
            
            guard documentState.isLoaded  else { return false }
            guard tableView.clickedRow >= 0 else { return false }
            return !(tableView.selectedRowIndexes.count > 1 && tableView.selectedRowIndexes.contains(tableView.clickedRow))
            
        }
            
        else if menuItem.action == #selector(smartTrim(_:)) || menuItem.action == #selector(resample(_:))
        {  // contents available / single target / from both menu / must be an area
            
            if menuItem.action == #selector(smartTrim(_:)) {
                guard documentState.isWriteable else { return false }
            }
            
            guard let content = documentContent else { return false }
            
            if tableView.clickedRow >= 0 {
                if tableView.selectedRowIndexes.count > 1 && tableView.selectedRowIndexes.contains(tableView.clickedRow) {
                    return false
                }
                let targetIndex = tableView.clickedRow
                if content.items[targetIndex] is PixelArea { return true }
            } else if tableView.selectedRowIndexes.count == 1 {
                if let targetIndex = tableView.selectedRowIndexes.first {
                    if content.items[targetIndex] is PixelArea { return true }
                }
                return false
            }
            
            return false
            
        }
            
        else if menuItem.action == #selector(paste(_:))
        {  // contents available / paste manager
            guard documentState.isWriteable else { return false }
            return documentExport?.canImportFromAdditionalPasteboard ?? false
        }
            
        else if menuItem.action == #selector(toggleHeader(_:))
        {
            return menuItem.identifier != .toggleTableColumnIdentifier
        }
            
        else if menuItem.action == #selector(toggleItemRepr(_:))
        {  // contents loaded
            return documentState.isLoaded
        }
            
        else if menuItem.action == #selector(create(_:))
            || menuItem.action == #selector(removeTag(_:))
        {  // contents writeable
            return documentState.isWriteable
        }
            
        else if menuItem.action == #selector(resetColumns(_:))
        {
            return true
        }
        
        return false
    }
    
    func numberOfItems(in menu: NSMenu) -> Int {
        if menu == tableRemoveTagsMenu
        {
            guard let collection = documentContent?.items else { return 0 }
            let selectedIndexes = selectedRowIndexes
            preparedSelectedItemCount = selectedIndexes.count
            let allTags = selectedIndexes
                .flatMap({ collection[$0].tags })
            preparedMenuTags = OrderedSet<String>(allTags)
            preparedMenuTagsAndCounts = allTags
                .reduce(into: [String: Int](), { $0[$1, default: 0] += 1 })
            return max(preparedMenuTags?.count ?? 0, 1)
        }
        return -1  // unchanged
    }
    
    func menu(_ menu: NSMenu, update item: NSMenuItem, at index: Int, shouldCancel: Bool) -> Bool {
        if menu == tableHeaderMenu {
            if item.identifier      == .toggleTableColumnIdentifier {
                item.state = UserDefaults.standard[.toggleTableColumnIdentifier]  ? .on : .off
            }
            else if item.identifier == .toggleTableColumnSimilarity {
                item.state = UserDefaults.standard[.toggleTableColumnSimilarity]  ? .on : .off
            }
            else if item.identifier == .toggleTableColumnTag {
                item.state = UserDefaults.standard[.toggleTableColumnTag]         ? .on : .off
            }
            else if item.identifier == .toggleTableColumnDescription {
                item.state = UserDefaults.standard[.toggleTableColumnDescription] ? .on : .off
            }
        }
        else if menu == tableRemoveTagsMenu {
            guard !shouldCancel else {
                preparedSelectedItemCount = nil
                preparedMenuTags = nil
                preparedMenuTagsAndCounts = nil
                return false
            }
            guard let selectedItemCount = preparedSelectedItemCount,
                let menuTags = preparedMenuTags,
                let menuTagsAndCounts = preparedMenuTagsAndCounts else
            { return false }
            guard index < menuTags.count else {
                item.title = NSLocalizedString("No tag attached", comment: "Content Tag Submenu")
                item.state = .off
                item.target = nil
                item.action = nil
                return false
            }
            let menuTitle = menuTags[index]
            let menuCount = menuTagsAndCounts[menuTitle] ?? 0
            item.title = "\(menuTitle) (\(menuCount))"
            item.state = menuCount >= selectedItemCount ? .on : .mixed
            item.target = self
            item.action = #selector(removeTag(_:))
        }
        else if menu == itemReprMenu {
            let useAlt: Bool = UserDefaults.standard[.usesAlternativeAreaRepresentation]
            itemReprAreaMenuItem.state    = useAlt ? .off : .on
            itemReprAreaAltMenuItem.state = useAlt ? .on : .off
        }
        return true
    }
    
    private func updateColumns() {
        var hiddenValue: Bool!
        
        hiddenValue = !UserDefaults.standard[.toggleTableColumnIdentifier]
        if columnIdentifier.isHidden != hiddenValue {
            columnIdentifier.isHidden = hiddenValue
        }
        
        hiddenValue = !UserDefaults.standard[.toggleTableColumnSimilarity]
        if columnSimilarity.isHidden != hiddenValue {
            columnSimilarity.isHidden = hiddenValue
        }
        
        hiddenValue = !UserDefaults.standard[.toggleTableColumnTag]
        if columnTag.isHidden != hiddenValue {
            columnTag.isHidden = hiddenValue
        }
        
        hiddenValue = !UserDefaults.standard[.toggleTableColumnDescription]
        if columnDescription.isHidden != hiddenValue {
            columnDescription.isHidden = hiddenValue
        }
    }
    
    private func deleteConfirmForItems(_ itemsToRemove: [ContentItem]) -> Bool {
        guard UserDefaults.standard[.confirmBeforeDelete] else { return true }
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Delete Confirm", comment: "Delete Confirm")
        if itemsToRemove.count > 1 {
            alert.informativeText = String(format: NSLocalizedString("Do you want to remove selected %d items?", comment: "Delete Confirm"), itemsToRemove.count)
        }
        else if let itemToRemove = itemsToRemove.first {
            alert.informativeText = String(format: NSLocalizedString("Do you want to remove selected item #%ld: %@?", comment: "Delete Confirm"), itemToRemove.id, itemToRemove.description)
        }
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("Confirm", comment: "Delete Confirm"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Delete Confirm"))
        return alert.runModal() == .alertFirstButtonReturn
    }
    
    @IBAction func locate(_ sender: Any) {
        guard let collection = documentContent?.items else { return }
        guard let targetIndex = selectedRowIndex else { return }
        
        let targetItem = collection[targetIndex]
        actionManager.contentActionConfirmed([targetItem])
    }
    
    @IBAction func relocate(_ sender: Any) {
        guard let collection = documentContent?.items else { return }
        guard let targetIndex = selectedRowIndex else { return }
        
        var panel: EditWindow?
        let targetItem = collection[targetIndex]
        if targetItem is PixelColor {
            panel = EditWindow.newEditCoordinatePanel()
        } else if targetItem is PixelArea {
            panel = EditWindow.newEditAreaPanel()
        }
        
        if let panel = panel {
            internalSelectContentItems(in: IndexSet(integer: targetIndex), byExtendingSelection: false)
            
            panel.loader = self
            panel.contentDelegate = self
            panel.contentItemSource = self
            panel.contentItem = targetItem
            panel.type = .edit

            view.window!.beginSheet(panel) { (resp) in
                if resp == .OK {
                    // do nothing
                }
            }
        }
    }
    
    @IBAction func tags(_ sender: NSMenuItem?) {
        guard let collection = documentContent?.items else { return }
        let rows = selectedRowIndexes
        let itemsToEdit = rows.map({ collection[$0] })
        
        let panel = EditWindow.newEditTagsPanel()
        internalSelectContentItems(in: rows, byExtendingSelection: false)
        
        panel.contentDelegate = self
        panel.contentItems = itemsToEdit
        panel.type = .edit
        
        view.window!.beginSheet(panel) { (resp) in
            if resp == .OK {
                // do nothing
            }
        }
    }
    
    @IBAction func create(_ sender: NSMenuItem?) {
        guard documentContent?.items != nil else { return }
        
        var panel: EditWindow?
        if sender == itemNewColorMenuItem {
            panel = EditWindow.newEditCoordinatePanel()
        } else if sender == itemNewAreaMenuItem {
            panel = EditWindow.newEditAreaPanel()
        }
        
        if let panel = panel {
            panel.loader = self
            panel.contentDelegate = self
            panel.contentItemSource = self
            
            panel.contentItem = nil
            panel.type = .add
            
            view.window!.beginSheet(panel) { (resp) in
                if resp == .OK {
                    // do nothing
                }
            }
        }
    }
    
    @IBAction func delete(_ sender: Any) {
        guard let collection = documentContent?.items else { return }
        let rows = selectedRowIndexes
        let itemsToRemove = rows.map({ collection[$0] })
        guard deleteConfirmForItems(itemsToRemove) else { return }
        internalDeleteContentItems(itemsToRemove)
        tableView.removeRows(at: rows, withAnimation: .effectFade)
    }
    
    @IBAction func copy(_ sender: Any) {
        guard let selectedItems = selectedContentItems else { return }
        guard let template = ExportManager.selectedTemplate else {
            presentError(ExportManager.Error.noTemplateSelected)
            return
        }
        if template.isAsync {
            copyItemsAsync(selectedItems, from: template)
        } else {
            copyItems(selectedItems, from: template)
        }
    }

    private func copyItems(_ items: [ContentItem], from template: Template) {
        do {
            if (items.count == 1) {
                try self.documentExport?.copyContentItem(items.first!)
            } else {
                try self.documentExport?.copyContentItems(items)
            }
        }
        catch {
            presentError(error)
        }
    }

    private func copyItemsAsync(_ items: [ContentItem], from template: Template) {
        extractItemsAsync(items, from: template) { [unowned self] in
            if (items.count == 1) {
                try self.documentExport?.copyContentItem(items.first!)
            } else {
                try self.documentExport?.copyContentItems(items)
            }
        }
    }
    
    @IBAction func paste(_ sender: Any) {
        guard let items = documentExport?.importFromAdditionalPasteboard() else { return }
        do {
            try importContentItems(items)
        } catch {
            presentError(error)
        }
    }
    
    @IBAction func resample(_ sender: Any) {
        guard let collection = documentContent?.items else { return }
        guard let targetIndex = selectedRowIndex else { return }
        guard let selectedArea = collection[targetIndex] as? PixelArea else { return }
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["png"]
        panel.beginSheetModal(for: view.window!) { [weak self] (resp) in
            if resp == .OK {
                if let url = panel.url {
                    self?.saveCroppedImage(of: selectedArea, to: url)
                }
            }
        }
    }
    
    private func saveCroppedImage(of area: PixelArea, to url: URL) {
        guard let data = documentImage?.pngRepresentation(of: area) else { return }
        do {
            try data.write(to: url)
        }
        catch {
            presentError(error)
        }
    }
    
    @IBAction func exportAs(_ sender: Any) {
        guard let selectedItems = selectedContentItems else { return }
        guard let template = ExportManager.selectedTemplate else {
            presentError(ExportManager.Error.noTemplateSelected)
            return
        }

        let panel = NSSavePanel()
        panel.allowedFileTypes = template.allowedExtensions
        panel.beginSheetModal(for: view.window!) { (resp) in
            if resp == .OK {
                if let url = panel.url {
                    if template.isAsync {
                        self.exportItemsAsync(selectedItems, from: template, to: url)
                    } else {
                        self.exportItems(selectedItems, from: template, to: url)
                    }
                }
            }
        }
    }
    
    private func exportItems(_ items: [ContentItem], from template: Template, to url: URL) {
        do {
            try documentExport?.exportContentItems(items, to: url)
        }
        catch {
            presentError(error)
        }
    }

    private func exportItemsAsync(_ items: [ContentItem], from template: Template, to url: URL) {
        extractItemsAsync(items, from: template) { [unowned self] in
            try self.documentExport?.exportContentItems(items, to: url)
        }
    }

    private func extractItemsAsync(_ items: [ContentItem], from template: Template, completionHandler completion: @escaping () throws -> Void) {
        let loadingAlert = NSAlert()
        loadingAlert.addButton(withTitle: NSLocalizedString("Cancel", comment: "copy(_:)"))
        loadingAlert.alertStyle = .informational
        loadingAlert.buttons.first?.isHidden = true
        let loadingIndicator = NSProgressIndicator(frame: CGRect(x: 0, y: 0, width: 24.0, height: 24.0))
        loadingIndicator.style = .spinning
        loadingIndicator.startAnimation(nil)
        loadingAlert.accessoryView = loadingIndicator
        loadingAlert.messageText = NSLocalizedString("Extract Snippets", comment: "copy(_:)")
        loadingAlert.informativeText = String(format: NSLocalizedString("Extract code snippets from template \"%@\"...", comment: "copy(_:)"), template.name)
        loadingAlert.beginSheetModal(for: view.window!) { (resp) in }
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            do {
                defer {
                    DispatchQueue.main.async {
                        loadingAlert.window.orderOut(self)
                        self.view.window?.endSheet(loadingAlert.window)
                    }
                }
                try completion()
            } catch {
                DispatchQueue.main.async { [unowned self] in
                    self.presentError(error)
                }
            }
        }
    }
    
    @IBAction func toggleHeader(_ sender: NSMenuItem) {
        var defaultKey: UserDefaults.Key?
        if sender.identifier == .toggleTableColumnIdentifier {
            defaultKey = .toggleTableColumnIdentifier
        }
        else if sender.identifier == .toggleTableColumnSimilarity {
            defaultKey = .toggleTableColumnSimilarity
        }
        else if sender.identifier == .toggleTableColumnTag {
            defaultKey = .toggleTableColumnTag
        }
        else if sender.identifier == .toggleTableColumnDescription {
            defaultKey = .toggleTableColumnDescription
        }
        if let key = defaultKey {
            let val: Bool = UserDefaults.standard[key]
            UserDefaults.standard[key] = !val
            sender.state = !val ? .on : .off
            updateColumns()
        }
    }
    
    @IBAction func toggleItemRepr(_ sender: NSMenuItem) {
        if sender == itemReprColorMenuItem {
            
        }
        else if sender == itemReprAreaMenuItem {
            UserDefaults.standard[.usesAlternativeAreaRepresentation] = false
        }
        else if sender == itemReprAreaAltMenuItem {
            UserDefaults.standard[.usesAlternativeAreaRepresentation] = true
        }
    }
    
    private func smartTrimPixelArea(_ item: PixelArea) throws -> ContentItem? {
        guard let croppedNSImage = documentImage?.toNSImage(of: item) else { return nil }
        
        let bestChildRect = OpenCVWrapper.bestChildRectangle(of: croppedNSImage)
        guard !bestChildRect.isEmpty else { return nil }
        
        let trimmedRect = PixelRect(CGRect(origin: bestChildRect.origin.offsetBy(item.rect.origin.toCGPoint()), size: bestChildRect.size))
        guard trimmedRect != item.rect else { return nil }
        
        return try updateContentItem(item, to: trimmedRect)
    }
    
    @IBAction func smartTrim(_ sender: NSMenuItem) {
        guard let collection = documentContent?.items else { return }
        guard let targetIndex = selectedRowIndex else { return }
        guard let selectedArea = collection[targetIndex] as? PixelArea else { return }
        do {
            guard let _ = try smartTrimPixelArea(selectedArea) else {
                NSSound.beep()
                return
            }
        } catch {
            presentError(error)
        }
    }
    
    @IBAction func removeTag(_ sender: NSMenuItem) {
        guard let parent = sender.menu else { return }
        guard let selectedItems = selectedContentItems,
            let menuTags = preparedMenuTags else { return }
        
        let targetTagIndex = parent.index(of: sender)
        let targetTag = menuTags[targetTagIndex]
        let copiedItems = selectedItems.map({ $0.copy() as! ContentItem })
        copiedItems.forEach({ $0.tags.remove(targetTag) })
        
        let itemIndexes = internalUpdateContentItems(copiedItems)
        let col = tableView.column(withIdentifier: .columnTag)
        tableView.reloadData(forRowIndexes: itemIndexes, columnIndexes: col >= 0 ? IndexSet(integer: col) : IndexSet())
        
        internalSelectContentItems(in: itemIndexes, byExtendingSelection: false)
    }
    
}

extension ContentController: NSTableViewDelegate, NSTableViewDataSource {
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        internalTableViewSelectionDidChange(notification)
    }
    
    private func internalTableViewSelectionDidChange(_ notification: Notification?) {
        guard let collection = documentContent?.items else { return }
        let realSelectedItems = tableView.selectedRowIndexes.map({ collection[$0] })
        actionManager.contentActionSelected(realSelectedItems)
        invalidateRestorableState()
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return documentContent?.items.count ?? 0
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 20
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let content = documentContent else { return nil }
        guard let tableColumn = tableColumn else { return nil }
        if let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as? ContentCellView {
            let col = tableColumn.identifier
            let item = content.items[row]
            if col == .columnIdentifier {
                cell.text = String(item.id)
            }
            else if col == .columnSimilarity {
                let similarity = String(Int(item.similarity * 100.0))
                cell.toolTip = usesDetailedToolTips ? String(format: NSLocalizedString("TOOLTIP_MODIFY_SIMILARITY", comment: "Tool Tip: Modify Similiarity"), similarity) : nil
                cell.text = similarity + "%"
            }
            else if col == .columnTag {
                if !item.tags.isEmpty {
                    
                    let allTags = item.tags.contents
                    
                    if let firstTag = allTags.first {
                        cell.normalTextColor = tagManager
                            .managedTag(of: firstTag)?
                            .color
                    }
                    
                    cell.text = "\u{25CF} " + allTags.joined(separator: "/")
                    
                    if usesDetailedToolTips {
                        
                        let attachedTags = tagManager
                            .managedTags(of: allTags)
                            .map({ $0.name })
                        
                        let attachedSet = Set(attachedTags)
                        let otherTags = allTags.filter({ !attachedSet.contains($0) })
                        
                        let chunkedAttachedTagsText = attachedTags.isEmpty ? "-" : attachedTags
                            .chunked(into: 6)
                            .reduce(into: [String](), { $0.append($1.joined(separator: ", ")) })
                            .joined(separator: ", \n")
                        
                        let chunkedOtherTagsText = otherTags.isEmpty ? "-" : otherTags
                            .chunked(into: 6)
                            .reduce(into: [String](), { $0.append($1.joined(separator: ", ")) })
                            .joined(separator: ", \n")
                        
                        cell.toolTip = String(format: NSLocalizedString("TOOLTIP_TAG_CELL_VIEW", comment: "Tool Tip: Tag Cell View"), chunkedAttachedTagsText, chunkedOtherTagsText)
                        cell.allowsExpansionToolTips = false
                        
                    } else {
                        cell.toolTip = nil
                        cell.allowsExpansionToolTips = true
                    }
                } else {
                    cell.normalTextColor = nil
                    cell.text = NSLocalizedString("None", comment: "None")
                    cell.toolTip = NSLocalizedString("No tag attached", comment: "Tool Tip: Tag Cell View")
                }
            }
            else if col == .columnDescription {
                if let color = item as? PixelColor {
                    cell.image = NSImage(color: color.pixelColorRep.toNSColor(), size: NSSize(width: 14, height: 14))
                    cell.toolTip = usesDetailedToolTips ? String(format: NSLocalizedString("TOOLTIP_DESC_PIXEL_COLOR", comment: "Tool Tip: Description of Pixel Color"), color.coordinate.description, color.cssString, color.cssRGBAString) : nil
                } else if let area = item as? PixelArea {
                    cell.image = NSImage(named: "JSTCropSmall")
                    cell.toolTip = usesDetailedToolTips ? String(format: NSLocalizedString("TOOLTIP_DESC_PIXEL_AREA", comment: "Tool Tip: Description of Pixel Area"), area.rect.origin.description, area.rect.opposite.description, area.rect.size.description) : nil
                }
                cell.text = item.description
            }
            return cell
        }
        return nil
    }
    
}

extension ContentController: ScreenshotLoader {
    
    func load(_ screenshot: Screenshot) throws {
        
        guard let _ = screenshot.content else
        {
            throw Screenshot.Error.invalidContent
        }
        
        self.screenshot = screenshot
        addCoordinateButton.isEnabled = true
        addCoordinateField.isEnabled = true
        
        if let undoManager = screenshot.undoManager {
            tableView.contextUndoManager = undoManager
            undoToken = NotificationCenter.default.observe(name: NSNotification.Name.NSUndoManagerDidUndoChange, object: undoManager) { [unowned self] _ in
                self.tableView.reloadData()
                self.internalSelectContentItems(in: self.delayedRowIndexes, byExtendingSelection: false)
                self.delayedRowIndexes = nil
            }
            redoToken = NotificationCenter.default.observe(name: NSNotification.Name.NSUndoManagerDidRedoChange, object: undoManager) { [unowned self] _ in
                self.tableView.reloadData()
                self.internalSelectContentItems(in: self.delayedRowIndexes, byExtendingSelection: false)
                self.delayedRowIndexes = nil
            }
        }
        
        tableView.reloadData()
        
    }
    
}

extension ContentController: NSMenuDelegateAlternate {
    
    // This is a work-around for the strange Cocoa NSMenuDelegate.
    func menuNeedsUpdateAlternate(_ altMenu: NSMenu) {
        var idx = 0
        for item in altMenu.items {
            if !menu(altMenu, update: item, at: idx, shouldCancel: false) {
                break
            }
            idx += 1
        }
    }
    
}

extension ContentController: TagImportSource {
    
    var importableTagNames: [String]? {
        guard let content = documentContent else { return nil }
        return OrderedSet<String>(content.items.flatMap({ $0.tags })).contents
    }
    
}

extension ContentController {
    
    @objc private func managedTagsDidLoadNotification(_ noti: NSNotification) {
        contentItemColorize()
    }
    
    @objc private func managedTagsDidChangeNotification(_ noti: NSNotification) {
        DispatchQueue.main.async { [weak self] in
            self?.contentItemColorize()
        }
    }
    
    private func contentItemColorize() {
        let col = tableView.column(withIdentifier: .columnTag)
        tableView.reloadData(
            forRowIndexes: IndexSet(integersIn: 0..<tableView.numberOfRows),
            columnIndexes: col >= 0 ? IndexSet(integer: col) : IndexSet()
        )
    }
    
}

extension ContentController: ShortcutGuideDataSource {

    var shortcutItems: [ShortcutItem] {
        return []
    }

}

