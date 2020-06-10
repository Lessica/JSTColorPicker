//
//  ContentController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/21/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

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

enum ContentError: LocalizedError {
    
    case itemExists(item: CustomStringConvertible)
    case itemDoesNotExist(item: CustomStringConvertible)
    case itemNotValid(item: CustomStringConvertible)
    case itemOutOfRange(item: CustomStringConvertible, range: CustomStringConvertible)
    case itemReachLimit(totalSpace: Int)
    case itemReachLimitBatch(moreSpace: Int)
    case itemConflict(item1: CustomStringConvertible, item2: CustomStringConvertible)
    case noDocumentLoaded
    case userAborted
    
    var failureReason: String? {
        switch self {
        case let .itemExists(item):
            return String(format: NSLocalizedString("This item %@ already exists.", comment: "ContentError"), item.description)
        case let .itemDoesNotExist(item):
            return String(format: NSLocalizedString("This item %@ does not exist.", comment: "ContentError"), item.description)
        case let .itemNotValid(item):
            return String(format: NSLocalizedString("This requested item %@ is not valid.", comment: "ContentError"), item.description)
        case let .itemOutOfRange(item, range):
            return String(format: NSLocalizedString("The requested item %@ is out of the document range %@.", comment: "ContentError"), item.description, range.description)
        case let .itemReachLimit(totalSpace):
            return String(format: NSLocalizedString("Maximum item count %d reached.", comment: "ContentError"), totalSpace)
        case let .itemReachLimitBatch(moreSpace):
            return String(format: NSLocalizedString("This operation requires %d more spaces.", comment: "ContentError"), moreSpace)
        case let .itemConflict(item1, item2):
            return String(format: NSLocalizedString("The requested item %@ conflicts with another item %@ in the document.", comment: "ContentError"), item1.description, item2.description)
        case .noDocumentLoaded:
            return NSLocalizedString("No document loaded.", comment: "ContentError")
        case .userAborted:
            return NSLocalizedString("User aborted.", comment: "ContentError")
        }
    }
    
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
    
    public weak var actionDelegate: ContentActionDelegate!
    public weak var tagListDataSource: TagListDataSource!
    
    internal weak var screenshot: Screenshot?
    private var content: Content? {
        return screenshot?.content
    }
    private var nextID: Int {
        if let lastID = content?.items.last?.id {
            return lastID + 1
        }
        return 1
    }
    private var nextSimilarity: Double {
        if let lastSimilarity = content?.items.last?.similarity {
            return lastSimilarity
        }
        return 1.0
    }
    
    private var undoToken: NotificationToken?
    private var redoToken: NotificationToken?
    
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
    @IBOutlet weak var columnIdentifier   : NSTableColumn!
    @IBOutlet weak var columnSimilarity   : NSTableColumn!
    @IBOutlet weak var columnTag          : NSTableColumn!
    @IBOutlet weak var columnDescription  : NSTableColumn!
    
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
        guard let collection = content?.items else { return nil }
        return selectedRowIndexes.map { collection[$0] }
    }
    
    private var preparedSelectedItemCount: Int?
    private var preparedMenuTags: OrderedSet<String>?
    private var preparedMenuTagsAndCounts: [String: Int]?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        addCoordinateButton.isEnabled = false
        addCoordinateField.isEnabled = false
        
        tableView.tableViewResponder = self
        tableView.registerForDraggedTypes([.color, .area])
        
        undoToken = NotificationCenter.default.observe(name: NSNotification.Name.NSUndoManagerDidUndoChange, object: undoManager) { [unowned self] (notification) in
            self.tableView.reloadData()
        }
        redoToken = NotificationCenter.default.observe(name: NSNotification.Name.NSUndoManagerDidRedoChange, object: undoManager) { [unowned self] (notification) in
            self.tableView.reloadData()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(applyPreferences(_:)), name: UserDefaults.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(managedTagsDidLoadNotification(_:)), name: NSNotification.Name.NSManagedObjectContextDidLoad, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(managedTagsDidChangeNotification(_:)), name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: nil)
        
        applyPreferences(nil)
    }
    
    @objc private func applyPreferences(_ notification: Notification?) {
        updateColumns()
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
        guard let content = content else { return }
        
        let row = tableView.row(for: sender)
        assert(row >= 0 && row < content.items.count)
        
        let value = sender.doubleValue
        if value >= 1 && value <= 100 {
            let item = content.items[row].copy() as! ContentItem
            item.similarity = min(max(value / 100.0, 0.01), 1.0)
            
            let itemIndexes = internalUpdateContentItems([item])
            let col = tableView.column(withIdentifier: .columnSimilarity)
            tableView.reloadData(forRowIndexes: itemIndexes, columnIndexes: col >= 0 ? IndexSet(integer: col) : IndexSet())
            return
        }
        
        let similarity = String(Int(content.items[row].similarity * 100.0))
        sender.stringValue = similarity + "%"
    }
    
    @IBAction func addCoordinateFieldChanged(_ sender: NSTextField) {
        guard let image = screenshot?.image else { return }
        
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
                throw ContentError.itemNotValid(item: inputVal)
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
                    throw ContentError.itemOutOfRange(item: coordinate, range: image.size)
                }
                
                do {
                    _ = try addContentItem(of: coordinate)
                } catch ContentError.itemExists {
                    try selectContentItem(of: coordinate)
                }
                
                sender.stringValue = ""
                addedOrSelected = true
                
            }
            else {
                
                let useAlt: Bool = UserDefaults.standard[.useAlternativeAreaRepresentation]
                
                var rect: PixelRect!
                if !useAlt {
                    rect = PixelRect(coordinate1: PixelCoordinate(x: x, y: y), coordinate2: PixelCoordinate(x: x2, y: y2))
                }
                else {
                    rect = PixelRect(origin: PixelCoordinate(x: x, y: y), size: PixelSize(width: x2, height: y2))
                }
                
                guard image.bounds.contains(rect) else {
                    throw ContentError.itemOutOfRange(item: rect, range: image.bounds)
                }
                
                do {
                    _ = try addContentItem(of: rect)
                } catch ContentError.itemExists {
                    try selectContentItem(of: rect)
                }
                
                sender.stringValue = ""
                addedOrSelected = true
                
            }
            
            if !addedOrSelected {
                throw ContentError.itemNotValid(item: inputVal)
            }
            
        } catch {
            presentError(error)
            makeFirstResponder(sender)
        }
        
    }
    
    @IBAction func addCoordinateAction(_ sender: NSButton) {
        if addCoordinateField.stringValue.isEmpty {
            if let event = view.window?.currentEvent {
                NSMenu.popUpContextMenu(itemNewMenu, with: event, for: sender)
            }
        } else {
            addCoordinateFieldChanged(addCoordinateField)
        }
    }
    
    deinit {
        debugPrint("- [ContentController deinit]")
    }
    
}

extension ContentController {
    
    @discardableResult
    private func internalAddContentItems(_ items: [ContentItem]) -> IndexSet {
        guard let content = content else { return IndexSet() }
        undoManager?.registerUndo(withTarget: self, handler: { $0.internalDeleteContentItems(items) })
        actionDelegate.contentActionAdded(items)
        var indexes = IndexSet()
        items.sorted(by: { $0.id < $1.id }).forEach { (item) in
            let idx = content.items.insertionIndexOf(item, isOrderedBefore: { $0.id < $1.id })
            content.items.insert(item, at: idx)
            indexes.insert(idx)
        }
        return indexes
    }
    
    @discardableResult
    private func internalDeleteContentItems(_ items: [ContentItem]) -> IndexSet {
        guard let content = content else { return IndexSet() }
        let itemIDs = Set(items.compactMap({ $0.id }))
        let itemsToRemove = content.items.filter({ itemIDs.contains($0.id) })
        undoManager?.registerUndo(withTarget: self, handler: { $0.internalAddContentItems(itemsToRemove) })
        actionDelegate.contentActionDeleted(items)
        let indexes = content.items
            .enumerated()
            .filter({ itemIDs.contains($1.id) })
            .reduce(into: IndexSet()) { $0.insert($1.offset) }
        content.items.remove(at: indexes)
        return indexes
    }
    
    @discardableResult
    private func internalUpdateContentItems(_ items: [ContentItem]) -> IndexSet {
        guard let content = content else { return IndexSet() }
        let itemIDs = Set(items.compactMap({ $0.id }))
        let itemsToRemove = content.items.filter({ itemIDs.contains($0.id) })
        undoManager?.registerUndo(withTarget: self, handler: { $0.internalUpdateContentItems(itemsToRemove) })
        actionDelegate.contentActionUpdated(items)
        content.items.removeAll(where: { itemIDs.contains($0.id) })
        var indexes = IndexSet()
        items.sorted(by: { $0.id < $1.id }).forEach { (item) in
            let idx = content.items.insertionIndexOf(item, isOrderedBefore: { $0.id < $1.id })
            content.items.insert(item, at: idx)
            indexes.insert(idx)
        }
        return indexes
    }
    
}

extension ContentController: ContentDataSource {
    
    func contentItem(of coordinate: PixelCoordinate) throws -> ContentItem {
        guard let image = screenshot?.image              else { throw ContentError.noDocumentLoaded }
        guard let color = image.color(at: coordinate)    else { throw ContentError.itemOutOfRange(item: coordinate, range: image.size) }
        return color
    }
    
    func contentItem(of rect: PixelRect) throws -> ContentItem {
        guard let image = screenshot?.image                                      else { throw ContentError.noDocumentLoaded }
        guard rect.hasStandardized && rect.size > PixelSize(width: 1, height: 1) else { throw ContentError.itemNotValid(item: rect) }
        guard let area = image.area(at: rect)                                    else { throw ContentError.itemOutOfRange(item: rect, range: image.size) }
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
        
        guard let content = content else { throw ContentError.noDocumentLoaded }
        
        let maximumItemCountEnabled: Bool = UserDefaults.standard[.maximumItemCountEnabled]
        if maximumItemCountEnabled {
            let maximumItemCount: Int = UserDefaults.standard[.maximumItemCount]
            guard content.items.count < maximumItemCount else { throw ContentError.itemReachLimit(totalSpace: maximumItemCount) }
        }
        guard content.items.last(where: { $0 == item }) == nil else { throw ContentError.itemExists(item: item) }
        
        item.id = nextID
        item.similarity = nextSimilarity
        
        internalAddContentItems([item])
        tableView.reloadData()
        
        return try selectContentItem(item, byExtendingSelection: false)
        
    }
    
    @discardableResult
    private func importContentItems(_ items: [ContentItem]) throws -> [ContentItem] {
        
        guard let content = content, let image = screenshot?.image else { throw ContentError.noDocumentLoaded }
        let maximumItemCountEnabled: Bool = UserDefaults.standard[.maximumItemCountEnabled]
        if maximumItemCountEnabled {
            let maximumItemCount: Int = UserDefaults.standard[.maximumItemCount]
            let totalSpace = content.items.count + items.count
            guard totalSpace <= maximumItemCount else { throw ContentError.itemReachLimitBatch(moreSpace: totalSpace - maximumItemCount) }
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
                guard !existingCoordinates.contains(coordinate) else { throw ContentError.itemExists(item: color) }
                guard let newItem = image.color(at: coordinate) else { throw ContentError.itemOutOfRange(item: coordinate, range: image.size)}
                newItem.copyFrom(color)
                relatedItem = newItem
            }
            else if let area = item as? PixelArea {
                let rect = area.rect
                guard !existingRects.contains(rect) else { throw ContentError.itemExists(item: area) }
                guard let newItem = image.area(at: rect) else { throw ContentError.itemOutOfRange(item: rect, range: image.size) }
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
        
        selectContentItems(in: IndexSet(integersIn: beginRows..<beginRows + relatedItems.count), byExtendingSelection: false)
        return relatedItems
        
    }
    
    @discardableResult
    private func selectContentItem(of coordinate: PixelCoordinate) throws -> ContentItem? {
        guard let image = screenshot?.image else { throw ContentError.noDocumentLoaded }
        guard let color = image.color(at: coordinate) else { throw ContentError.itemOutOfRange(item: coordinate, range: image.size) }
        return try selectContentItem(color, byExtendingSelection: false)
    }
    
    @discardableResult
    private func selectContentItem(of rect: PixelRect) throws -> ContentItem? {
        
        guard let image = screenshot?.image   else { throw ContentError.noDocumentLoaded }
        guard let area = image.area(at: rect) else { throw ContentError.itemOutOfRange(item: rect, range: image.size) }
        
        return try selectContentItem(area, byExtendingSelection: false)
        
    }
    
    func selectContentItem(_ item: ContentItem, byExtendingSelection extend: Bool) throws -> ContentItem? {
        
        guard let content = content                              else { throw ContentError.noDocumentLoaded }
        guard let itemIndex = content.items.firstIndex(of: item) else { throw ContentError.itemDoesNotExist(item: item) }
        
        selectContentItems(in: IndexSet(integer: itemIndex), byExtendingSelection: extend)
        return item
        
    }
    
    func deselectContentItem(_ item: ContentItem) throws -> ContentItem? {
        
        guard let content = content                              else { throw ContentError.noDocumentLoaded }
        guard let itemIndex = content.items.firstIndex(of: item) else { throw ContentError.itemDoesNotExist(item: item) }
        
        tableView.deselectRow(itemIndex)
        makeFirstResponder(tableView)
        return item
        
    }
    
    func deselectAllContentItems() {
        tableView.deselectAll(nil)
    }
    
    private func selectContentItems(in set: IndexSet, byExtendingSelection extend: Bool) {
        if !set.isEmpty, let lastIndex = set.last {
            if tableView.selectedRowIndexes != set {
                tableView.selectRowIndexes(set, byExtendingSelection: extend)
            } else {
                internalTableViewSelectionDidChange(nil)
            }
            tableView.scrollRowToVisible(lastIndex)
            makeFirstResponder(tableView)
        }
        else {
            tableView.deselectAll(nil)
        }
    }
    
    func deleteContentItem(of coordinate: PixelCoordinate) throws -> ContentItem? {
        
        guard let content = content else { throw ContentError.noDocumentLoaded }
        guard let item = content.lazyColors.last(where: { $0.coordinate == coordinate })
            ?? content.lazyAreas.last(where: { $0.rect.contains(coordinate) })
            else { throw ContentError.itemDoesNotExist(item: coordinate) }
        
        return try deleteContentItem(item)
        
    }
    
    func deleteContentItem(_ item: ContentItem) throws -> ContentItem? {
        
        guard let content = content                      else { throw ContentError.noDocumentLoaded }
        guard content.items.firstIndex(of: item) != nil  else { throw ContentError.itemDoesNotExist(item: item) }
        guard deleteConfirmForItems([item])              else { throw ContentError.userAborted }
        
        let itemIndexes = internalDeleteContentItems([item])
        tableView.removeRows(at: itemIndexes, withAnimation: .effectFade)
        return item
        
    }
    
    func updateContentItem(_ item: ContentItem, to coordinate: PixelCoordinate) throws -> ContentItem? {
        
        guard let content = content, let image = screenshot?.image                              else { throw ContentError.noDocumentLoaded }
        guard content.items.first(where: { $0.id == item.id }) != nil                           else { throw ContentError.itemDoesNotExist(item: item) }
        if let conflictItem = content.lazyColors.first(where: { $0.coordinate == coordinate })       { throw ContentError.itemConflict(item1: coordinate, item2: conflictItem) }
        guard let replItem = image.color(at: coordinate)                                        else { throw ContentError.itemOutOfRange(item: coordinate, range: image.size) }
        
        replItem.copyFrom(item)
        
        let itemIndexes = internalUpdateContentItems([replItem])
        let col = tableView.column(withIdentifier: .columnDescription)
        tableView.reloadData(forRowIndexes: itemIndexes, columnIndexes: col >= 0 ? IndexSet(integer: col) : IndexSet())
        
        return try selectContentItem(replItem, byExtendingSelection: false)
        
    }
    
    func updateContentItem(_ item: ContentItem, to rect: PixelRect) throws -> ContentItem? {
        
        guard let content = content, let image = screenshot?.image                              else { throw ContentError.noDocumentLoaded }
        guard content.items.first(where: { $0.id == item.id }) != nil                           else { throw ContentError.itemDoesNotExist(item: item) }
        if let conflictItem = content.lazyAreas.first(where: { $0.rect == rect })                    { throw ContentError.itemConflict(item1: rect, item2: conflictItem) }
        guard let replItem = image.area(at: rect)                                               else { throw ContentError.itemOutOfRange(item: rect, range: image.size) }
        
        replItem.copyFrom(item)
        
        let itemIndexes = internalUpdateContentItems([replItem])
        let col = tableView.column(withIdentifier: .columnDescription)
        tableView.reloadData(forRowIndexes: itemIndexes, columnIndexes: col >= 0 ? IndexSet(integer: col) : IndexSet())
        
        return try selectContentItem(replItem, byExtendingSelection: false)
        
    }
    
    func updateContentItem(_ item: ContentItem) throws -> ContentItem? {
        
        guard let content = content                                                   else { throw ContentError.noDocumentLoaded }
        guard content.items.first(where: { $0.id == item.id }) != nil                 else { throw ContentError.itemDoesNotExist(item: item) }
        
        let replItem = item.copy() as! ContentItem
        let itemIndexes = internalUpdateContentItems([replItem])
        tableView.reloadData(forRowIndexes: itemIndexes, columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns))
        
        return try selectContentItem(replItem, byExtendingSelection: false)
        
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

extension ContentController: NSMenuItemValidation, NSMenuDelegate {
    
    func menuWillOpen(_ menu: NSMenu) {
        // menu item without action
        if menu == tableMenu {
            if content != nil {
                tableRemoveTagsMenuItem.isEnabled = tableView.clickedRow >= 0 || tableView.selectedRowIndexes.count > 0
            } else {
                tableRemoveTagsMenuItem.isEnabled = false
            }
        }
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        // menu item with action
        if menuItem.action == #selector(delete(_:))
            || menuItem.action == #selector(copy(_:))
            || menuItem.action == #selector(exportAs(_:))
        {  // contents available / multiple targets / from both menu
            guard content != nil else { return false }
            return tableView.clickedRow >= 0 || tableView.selectedRowIndexes.count > 0
        }
        else if menuItem.action == #selector(locate(_:)) || menuItem.action == #selector(relocate(_:))
        {  // contents available / single target / from right click menu
            guard content != nil            else { return false }
            guard tableView.clickedRow >= 0 else { return false }
            return !(tableView.selectedRowIndexes.count > 1 && tableView.selectedRowIndexes.contains(tableView.clickedRow))
        }
        else if menuItem.action == #selector(smartTrim(_:)) || menuItem.action == #selector(saveAs(_:))
        {  // contents available / single target / from both menu / must be an area
            guard let content = content else { return false }
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
            guard content != nil else { return false }
            return screenshot?.export.canImportFromAdditionalPasteboard ?? false
        }
        else if menuItem.action == #selector(toggleHeader(_:))
        {
            if menuItem.identifier == .toggleTableColumnIdentifier {
                return false
            }
            return true
        }
        else if menuItem.action == #selector(create(_:))
            || menuItem.action == #selector(toggleItemRepr(_:))
            || menuItem.action == #selector(removeTag(_:))
        {  // contents available
            guard content != nil else { return false }
            return true
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
            guard let collection = content?.items else { return 0 }
            let selectedIndexes = selectedRowIndexes
            preparedSelectedItemCount = selectedIndexes.count
            let allTags = selectedIndexes
                .flatMap({ collection[$0].tags })
            preparedMenuTags = OrderedSet<String>(allTags)
            preparedMenuTagsAndCounts = allTags
                .reduce(into: [String: Int](), { $0[$1, default: 0] += 1 })
            return preparedMenuTags?.count ?? 0
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
                let menuTitle = preparedMenuTags?[index],
                let menuCount = preparedMenuTagsAndCounts?[menuTitle] else
            { return false }
            item.title = "\(menuTitle) (\(menuCount))"
            item.state = menuCount >= selectedItemCount ? .on : .mixed
            item.target = self
            item.action = #selector(removeTag(_:))
        }
        else if menu == itemReprMenu {
            let useAlt: Bool = UserDefaults.standard[.useAlternativeAreaRepresentation]
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
        else {
            alert.informativeText = String(format: NSLocalizedString("Do you want to remove selected item %@?", comment: "Delete Confirm"), itemsToRemove.first?.description ?? "(null)")
        }
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("Confirm", comment: "Delete Confirm"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Delete Confirm"))
        return alert.runModal() == .alertFirstButtonReturn
    }
    
    @IBAction func locate(_ sender: Any) {
        guard let collection = content?.items else { return }
        guard let targetIndex = selectedRowIndex else { return }
        
        let targetItem = collection[targetIndex]
        actionDelegate.contentActionConfirmed([targetItem])
    }
    
    @IBAction func relocate(_ sender: Any) {
        guard let window = view.window else { return }
        guard let collection = content?.items else { return }
        guard let targetIndex = selectedRowIndex else { return }
        
        var panel: EditWindow?
        let targetItem = collection[targetIndex]
        if targetItem is PixelColor {
            panel = EditWindow.newEditCoordinatePanel()
        } else if targetItem is PixelArea {
            panel = EditWindow.newEditAreaPanel()
        }
        
        if let panel = panel {
            
            panel.loader = self
            panel.contentDelegate = self
            panel.contentDataSource = self

            panel.contentItem = targetItem
            panel.isAdd = false
            
            window.beginSheet(panel) { (resp) in
                if resp == .OK {
                    // do nothing
                }
            }
            
        }
    }
    
    @IBAction func create(_ sender: NSMenuItem?) {
        guard let window = view.window else { return }
        guard content?.items != nil else { return }
        
        var panel: EditWindow?
        if sender == itemNewColorMenuItem {
            panel = EditWindow.newEditCoordinatePanel()
        } else if sender == itemNewAreaMenuItem {
            panel = EditWindow.newEditAreaPanel()
        }
        
        if let panel = panel {
            
            panel.loader = self
            panel.contentDelegate = self
            panel.contentDataSource = self
            
            panel.contentItem = nil
            panel.isAdd = true
            
            window.beginSheet(panel) { (resp) in
                if resp == .OK {
                    // do nothing
                }
            }
            
        }
    }
    
    @IBAction func delete(_ sender: Any) {
        guard let collection = content?.items else { return }
        let rows = selectedRowIndexes
        let itemsToRemove = rows.map({ collection[$0] })
        guard deleteConfirmForItems(itemsToRemove) else { return }
        internalDeleteContentItems(itemsToRemove)
        tableView.removeRows(at: rows, withAnimation: .effectFade)
    }
    
    @IBAction func copy(_ sender: Any) {
        guard let selectedItems = selectedContentItems else { return }
        do {
            if (selectedItems.count == 1) {
                try screenshot?.export.copyContentItem(selectedItems.first!)
            } else {
                try screenshot?.export.copyContentItems(selectedItems)
            }
        }
        catch {
            presentError(error)
        }
    }
    
    @IBAction func paste(_ sender: Any) {
        guard let items = screenshot?.export.importFromAdditionalPasteboard() else { return }
        do {
            try importContentItems(items)
        } catch {
            presentError(error)
        }
    }
    
    @IBAction func saveAs(_ sender: Any) {
        guard let collection = content?.items else { return }
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
        guard let data = screenshot?.image?.pngRepresentation(of: area) else { return }
        do {
            try data.write(to: url)
        }
        catch {
            presentError(error)
        }
    }
    
    @IBAction func exportAs(_ sender: Any) {
        guard let selectedItems = selectedContentItems else { return }
        do {
            guard let template = screenshot?.export.selectedTemplate else { throw ExportError.noTemplateSelected }
            let panel = NSSavePanel()
            panel.allowedFileTypes = template.allowedExtensions
            panel.beginSheetModal(for: view.window!) { (resp) in
                if resp == .OK {
                    if let url = panel.url {
                        self.exportItems(selectedItems, to: url)
                    }
                }
            }
        }
        catch {
            presentError(error)
        }
    }
    
    private func exportItems(_ items: [ContentItem], to url: URL) {
        do {
            try screenshot?.export.exportItems(items, to: url)
        }
        catch {
            presentError(error)
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
            UserDefaults.standard[.useAlternativeAreaRepresentation] = false
        }
        else if sender == itemReprAreaAltMenuItem {
            UserDefaults.standard[.useAlternativeAreaRepresentation] = true
        }
    }
    
    private func smartTrimPixelArea(_ item: PixelArea) throws -> ContentItem? {
        guard let croppedNSImage = screenshot?.image?.toNSImage(of: item) else { return nil }
        
        let bestChildRect = OpenCVWrapper.bestChildRectangle(of: croppedNSImage)
        guard !bestChildRect.isEmpty else { return nil }
        
        let trimmedRect = PixelRect(CGRect(origin: bestChildRect.origin.offsetBy(item.rect.origin.toCGPoint()), size: bestChildRect.size))
        guard trimmedRect != item.rect else { return nil }
        
        return try updateContentItem(item, to: trimmedRect)
    }
    
    @IBAction func smartTrim(_ sender: NSMenuItem) {
        guard let collection = content?.items else { return }
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
    }
    
}

extension ContentController: NSTableViewDelegate, NSTableViewDataSource {
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        internalTableViewSelectionDidChange(notification)
    }
    
    private func internalTableViewSelectionDidChange(_ notification: Notification?) {
        guard let collection = content?.items else { return }
        let realSelectedItems = tableView.selectedRowIndexes.map({ collection[$0] })
        actionDelegate.contentActionSelected(realSelectedItems)
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return content?.items.count ?? 0
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 20
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let content = content else { return nil }
        guard let tableColumn = tableColumn else { return nil }
        if let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as? NSTableCellView {
            let col = tableColumn.identifier
            let item = content.items[row]
            if col == .columnIdentifier {
                cell.textField?.stringValue = String(item.id)
            }
            else if col == .columnSimilarity {
                let similarity = String(Int(item.similarity * 100.0))
                cell.textField?.toolTip = String(format: NSLocalizedString("TOOLTIP_MODIFY_SIMILARITY", comment: "Tool Tip: Modify Similiarity"), similarity)
                cell.textField?.stringValue = similarity + "%"
            }
            else if col == .columnTag {
                if let firstTag = item.tags.first {
                    cell.textField?.stringValue = "\u{25CF} \(firstTag)"
                    cell.textField?.textColor = tagListDataSource.managedTag(of: firstTag)?.color
                } else {
                    cell.textField?.stringValue = NSLocalizedString("None", comment: "None")
                    cell.textField?.textColor = nil
                }
            }
            else if col == .columnDescription {
                if let color = item as? PixelColor {
                    cell.imageView?.image = NSImage(color: color.pixelColorRep.toNSColor(), size: NSSize(width: 14, height: 14))
                    cell.textField?.toolTip = String(format: NSLocalizedString("TOOLTIP_DESC_PIXEL_COLOR", comment: "Tool Tip: Description of Pixel Color"), color.coordinate.description, color.cssString, color.cssRGBAString)
                }
                else if let area = item as? PixelArea {
                    cell.imageView?.image = NSImage(named: "JSTCropSmall")
                    cell.textField?.toolTip = String(format: NSLocalizedString("TOOLTIP_DESC_PIXEL_AREA", comment: "Tool Tip: Description of Pixel Area"), area.rect.origin.description, area.rect.opposite.description, area.rect.size.description)
                }
                cell.textField?.stringValue = item.description
            }
            return cell
        }
        return nil
    }
    
}

extension ContentController: ScreenshotLoader {
    
    func load(_ screenshot: Screenshot) throws {
        guard let _ = screenshot.content else {
            throw ScreenshotError.invalidContent
        }
        self.screenshot = screenshot
        addCoordinateButton.isEnabled = true
        addCoordinateField.isEnabled = true
        
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

