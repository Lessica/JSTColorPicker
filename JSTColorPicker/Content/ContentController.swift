//
//  ContentController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/21/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

extension NSUserInterfaceItemIdentifier {
    
    static let toggleTableColumnID          = NSUserInterfaceItemIdentifier("toggle-id")
    static let toggleTableColumnDescription = NSUserInterfaceItemIdentifier("toggle-desc")
    
}

extension NSUserInterfaceItemIdentifier {
    
    static let columnID          = NSUserInterfaceItemIdentifier("col-id")
    static let columnDescription = NSUserInterfaceItemIdentifier("col-desc")
    
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
            return String(format: NSLocalizedString("The requested item conflicts with another item in the document.", comment: "ContentError"), item1.description, item2.description)
        case .noDocumentLoaded:
            return NSLocalizedString("No document loaded.", comment: "ContentError")
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
    @discardableResult
    func makeFirstResponder(_ responder: NSResponder) -> Bool {
        guard let window = view.window else { return false }
        return window.makeFirstResponder(responder)
    }
}

class ContentController: NSViewController {
    
    public weak var actionDelegate: ContentActionDelegate!
    
    internal weak var screenshot: Screenshot?
    fileprivate var content: Content? {
        return screenshot?.content
    }
    fileprivate var nextID: Int {
        if let maxID = content?.items.last?.id {
            return maxID + 1
        }
        return 1
    }
    
    fileprivate var undoToken: NotificationToken?
    fileprivate var redoToken: NotificationToken?
    
    @IBOutlet var tableMenu: NSMenu!
    @IBOutlet var tableHeaderMenu: NSMenu!
    @IBOutlet var itemReprMenu: NSMenu!
    @IBOutlet var itemReprAreaMenuItem: NSMenuItem!
    @IBOutlet var itemReprAreaAltMenuItem: NSMenuItem!
    
    @IBOutlet weak var tableView: ContentTableView!
    @IBOutlet weak var columnID: NSTableColumn!
    @IBOutlet weak var columnDescription: NSTableColumn!
    
    @IBOutlet weak var addCoordinateButton: NSButton!
    @IBOutlet weak var addCoordinateField: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        addCoordinateButton.isEnabled = false
        addCoordinateField.isEnabled = false
        
        tableView.tableViewResponder = self
        tableView.registerForDraggedTypes([.content])
        
        undoToken = NotificationCenter.default.observe(name: NSNotification.Name.NSUndoManagerDidUndoChange, object: undoManager) { [unowned self] (notification) in
            self.tableView.reloadData()
        }
        redoToken = NotificationCenter.default.observe(name: NSNotification.Name.NSUndoManagerDidRedoChange, object: undoManager) { [unowned self] (notification) in
            self.tableView.reloadData()
        }
        tableView.reloadData()
        
        NotificationCenter.default.addObserver(self, selector: #selector(loadPreferences(_:)), name: UserDefaults.didChangeNotification, object: nil)
        loadPreferences(nil)
    }
    
    @objc fileprivate func loadPreferences(_ notification: Notification?) {
        updateColumns()
    }
    
    override func willPresentError(_ error: Error) -> Error {
        let error = super.willPresentError(error)
        debugPrint(error.localizedDescription)
        return error
    }
    
    @IBAction func resetColumns(_ sender: NSMenuItem) {
        UserDefaults.standard.removeObject(forKey: .toggleTableColumnID)
        UserDefaults.standard.removeObject(forKey: .toggleTableColumnDescription)
        
        columnID.width = 30.0
        columnDescription.width = 200.0
        
        tableView.tableColumns.forEach({ tableView.removeTableColumn($0) })
        let tableCols: [NSTableColumn] = [
            columnID,
            columnDescription
        ]
        tableCols.forEach({ tableView.addTableColumn($0) })
        
        updateColumns()
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
                    if let item = try addContentItem(of: coordinate) {
                        if let _ = try selectContentItem(item, byExtendingSelection: false) {
                            sender.stringValue = ""
                            addedOrSelected = true
                        }
                    }
                }
                catch ContentError.itemExists {
                    if let _ = try selectContentItem(of: coordinate) {
                        sender.stringValue = ""
                        addedOrSelected = true
                    }
                }
                
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
                    if let item = try addContentItem(of: rect) {
                        if let _ = try selectContentItem(item, byExtendingSelection: false) {
                            sender.stringValue = ""
                            addedOrSelected = true
                        }
                    }
                }
                catch ContentError.itemExists {
                    if let _ = try selectContentItem(of: rect) {
                        sender.stringValue = ""
                        addedOrSelected = true
                    }
                }
                
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
        addCoordinateFieldChanged(addCoordinateField)
    }
    
    deinit {
        debugPrint("- [ContentController deinit]")
    }
    
}

extension ContentController {
    
    fileprivate func internalAddContentItems(_ items: [ContentItem]) {
        
        guard let content = content else { return }
        
        undoManager?.beginUndoGrouping()
        undoManager?.registerUndo(withTarget: self, handler: { targetSelf in
            targetSelf.internalDeleteContentItems(items)  // memory captured and managed by UndoManager
        })
        undoManager?.endUndoGrouping()
        
        actionDelegate.contentActionAdded(items)
        items.forEach { (item) in
            let idx = content.items.insertionIndexOf(item, isOrderedBefore: { $0.id < $1.id })
            content.items.insert(item, at: idx)
        }
        
    }
    
    fileprivate func internalDeleteContentItems(_ items: [ContentItem]) {
        
        guard let content = content else { return }
        
        undoManager?.beginUndoGrouping()
        undoManager?.registerUndo(withTarget: self, handler: { (targetSelf) in
            targetSelf.internalAddContentItems(items)  // memory captured and managed by UndoManager
        })
        undoManager?.endUndoGrouping()
        
        actionDelegate.contentActionDeleted(items)
        content.items.removeAll(where: { items.contains($0) })
        
    }
    
    fileprivate func internalUpdateContentItems(_ items: [ContentItem]) {
        
        guard let content = content else { return }
        
        let itemIDs = items.compactMap({ $0.id })
        let itemsToRemove = content.items.filter({ itemIDs.contains($0.id) })
        
        undoManager?.beginUndoGrouping()
        undoManager?.registerUndo(withTarget: self, handler: { (targetSelf) in
            targetSelf.internalUpdateContentItems(itemsToRemove)  // memory captured and managed by UndoManager
        })
        undoManager?.endUndoGrouping()
        
        actionDelegate.contentActionUpdated(items)
        content.items.removeAll(where: { itemIDs.contains($0.id) })
        items.forEach { (item) in
            let idx = content.items.insertionIndexOf(item, isOrderedBefore: { $0.id < $1.id })
            content.items.insert(item, at: idx)
        }
        
    }
    
}

extension ContentController: ContentResponder {
    
    func addContentItem(of coordinate: PixelCoordinate) throws -> ContentItem? {
        guard let image = screenshot?.image else { throw ContentError.noDocumentLoaded }
        guard let color = image.color(at: coordinate) else { throw ContentError.itemOutOfRange(item: coordinate, range: image.size) }
        return try addContentItem(color)
    }
    
    func addContentItem(of rect: PixelRect) throws -> ContentItem? {
        guard let image = screenshot?.image else { throw ContentError.noDocumentLoaded }
        guard rect.size > PixelSize(width: 1, height: 1) else { throw ContentError.itemNotValid(item: rect) }
        guard let area = image.area(at: rect) else { throw ContentError.itemOutOfRange(item: rect, range: image.size) }
        return try addContentItem(area)
    }
    
    fileprivate func addContentItem(_ item: ContentItem) throws -> ContentItem? {
        guard let content = content else { throw ContentError.noDocumentLoaded }
        let maximumItemCountEnabled: Bool = UserDefaults.standard[.maximumItemCountEnabled]
        if maximumItemCountEnabled {
            let maximumItemCount: Int = UserDefaults.standard[.maximumItemCount]
            guard content.items.count < maximumItemCount else { throw ContentError.itemReachLimit(totalSpace: maximumItemCount) }
        }
        guard content.items.last(where: { $0 == item }) == nil else { throw ContentError.itemExists(item: item) }
        
        item.id = nextID
        internalAddContentItems([item])
        tableView.reloadData()
        
        return try selectContentItem(item, byExtendingSelection: false)
    }
    
    @discardableResult
    fileprivate func importContentItems(_ items: [ContentItem]) throws -> [ContentItem]? {
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
                relatedItem = newItem
            }
            else if let area = item as? PixelArea {
                let rect = area.rect
                guard !existingRects.contains(rect) else { throw ContentError.itemExists(item: area) }
                guard let newItem = image.area(at: rect) else { throw ContentError.itemOutOfRange(item: rect, range: image.size) }
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
    
    fileprivate func selectContentItem(of coordinate: PixelCoordinate) throws -> ContentItem? {
        guard let image = screenshot?.image else { throw ContentError.noDocumentLoaded }
        guard let color = image.color(at: coordinate) else { throw ContentError.itemOutOfRange(item: coordinate, range: image.size) }
        return try selectContentItem(color, byExtendingSelection: false)
    }
    
    fileprivate func selectContentItem(of rect: PixelRect) throws -> ContentItem? {
        guard let image = screenshot?.image else { throw ContentError.noDocumentLoaded }
        guard let area = image.area(at: rect) else { throw ContentError.itemOutOfRange(item: rect, range: image.size) }
        return try selectContentItem(area, byExtendingSelection: false)
    }
    
    func selectContentItem(_ item: ContentItem?, byExtendingSelection extend: Bool) throws -> ContentItem? {
        if let item = item {
            guard let content = content else { throw ContentError.noDocumentLoaded }
            guard let itemIndex = content.items.firstIndex(of: item) else { throw ContentError.itemDoesNotExist(item: item) }
            tableView.selectRowIndexes(IndexSet(integer: itemIndex), byExtendingSelection: extend)
            tableView.scrollRowToVisible(itemIndex)
            makeFirstResponder(tableView)
        }
        else {
            tableView.deselectAll(nil)
        }
        return item
    }
    
    func deselectContentItem(_ item: ContentItem) throws -> ContentItem? {
        guard let content = content else { throw ContentError.noDocumentLoaded }
        guard let itemIndex = content.items.firstIndex(of: item) else { throw ContentError.itemDoesNotExist(item: item) }
        tableView.deselectRow(itemIndex)
        //tableView.scrollRowToVisible(itemIndex)
        makeFirstResponder(tableView)
        return item
    }
    
    fileprivate func selectContentItems(in set: IndexSet, byExtendingSelection extend: Bool) {
        if !set.isEmpty, let lastIndex = set.last {
            tableView.selectRowIndexes(set, byExtendingSelection: extend)
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
        guard let content = content else { throw ContentError.noDocumentLoaded }
        guard let itemIndex = content.items.firstIndex(of: item) else { throw ContentError.itemDoesNotExist(item: item) }
        guard deleteConfirmForItems([item]) else { return nil }
        internalDeleteContentItems([item])
        tableView.removeRows(at: IndexSet(integer: itemIndex), withAnimation: .effectFade)
        return item
    }
    
    func updateContentItem(_ item: ContentItem, to coordinate: PixelCoordinate) throws -> ContentItem? {
        guard let content = content else { throw ContentError.noDocumentLoaded }
        guard content.items.first(where: { $0 == item }) != nil else { throw ContentError.itemDoesNotExist(item: item) }
        guard content.lazyColors.first(where: { $0.coordinate == coordinate }) == nil else { throw ContentError.itemConflict(item1: coordinate, item2: item) }
        guard let image = screenshot?.image else { throw ContentError.noDocumentLoaded }
        guard let color = image.color(at: coordinate) else { throw ContentError.itemOutOfRange(item: coordinate, range: image.size) }
        
        color.copyFrom(item)
        return try updateContentItem(color)
    }
    
    func updateContentItem(_ item: ContentItem, to rect: PixelRect) throws -> ContentItem? {
        guard let content = content else { throw ContentError.noDocumentLoaded }
        guard content.items.first(where: { $0 == item }) != nil else { throw ContentError.itemDoesNotExist(item: item) }
        guard content.lazyAreas.first(where: { $0.rect == rect }) == nil else { throw ContentError.itemConflict(item1: rect, item2: item) }
        guard let image = screenshot?.image else { throw ContentError.noDocumentLoaded }
        guard let area = image.area(at: rect) else { throw ContentError.itemOutOfRange(item: rect, range: image.size) }
        
        area.copyFrom(item)
        return try updateContentItem(area)
    }
    
    func updateContentItem(_ item: ContentItem) throws -> ContentItem? {
        internalUpdateContentItems([item])
        tableView.reloadData()
        return try selectContentItem(item, byExtendingSelection: false)
    }
    
}

extension ContentController: ContentTableViewResponder {
    
    @IBAction func tableViewAction(_ sender: ContentTableView) {
        // replaced by -tableViewSelectionDidChange(_:)
    }
    
    @IBAction func tableViewDoubleAction(_ sender: ContentTableView) {
        guard let collection = content?.items else { return }
        let selectedItems = (tableView.clickedRow >= 0 ? IndexSet(integer: tableView.clickedRow) : IndexSet(tableView.selectedRowIndexes))
            .filteredIndexSet(includeInteger: { $0 < collection.count })
            .map({ collection[$0] })
        actionDelegate.contentActionConfirmed(selectedItems)
    }
    
}

extension ContentController: NSUserInterfaceValidations, NSMenuDelegate {
    
    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        guard let content = content else { return false }
        if item.action == #selector(delete(_:)) || item.action == #selector(copy(_:)) || item.action == #selector(exportAs(_:)) {
            return tableView.clickedRow >= 0 || tableView.selectedRowIndexes.count > 0
        }
        else if item.action == #selector(locate(_:)) {
            guard tableView.clickedRow >= 0 else { return false }
            if tableView.selectedRowIndexes.count > 1 && tableView.selectedRowIndexes.contains(tableView.clickedRow) { return false }
            return true
        }
        else if item.action == #selector(smartTrim(_:)) {
            guard tableView.clickedRow >= 0 || tableView.selectedRowIndexes.count == 1 else { return false }
            if let targetIndex = (tableView.clickedRow >= 0 && !tableView.selectedRowIndexes.contains(tableView.clickedRow)) ? tableView.clickedRow : tableView.selectedRowIndexes.first {
                if let _ = content.items[targetIndex] as? PixelArea { return true }
            }
        }
        else if item.action == #selector(saveAs(_:)) {
            guard tableView.clickedRow >= 0 else { return false }
            if tableView.selectedRowIndexes.count > 1 && tableView.selectedRowIndexes.contains(tableView.clickedRow) { return false }
            if let _ = content.items[tableView.clickedRow] as? PixelArea { return true }
        }
        else if item.action == #selector(paste(_:)) {
            return screenshot?.export.canImportFromAdditionalPasteboard ?? false
        }
        else if item.action == #selector(toggleHeader(_:)) {
            if let menuItem = item as? NSMenuItem {
                if menuItem.identifier == .toggleTableColumnID {
                    return false
                }
                return true
            }
            return false
        }
        else if item.action == #selector(resetColumns(_:)) {
            return true
        }
        else if item.action == #selector(toggleItemRepr(_:)) {
            return true
        }
        return false
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu == tableHeaderMenu {
            menu.items.forEach { (menuItem) in
                if menuItem.identifier == .toggleTableColumnID {
                    menuItem.state = UserDefaults.standard[.toggleTableColumnID] ? .on : .off
                }
                else if menuItem.identifier == .toggleTableColumnDescription {
                    menuItem.state = UserDefaults.standard[.toggleTableColumnDescription] ? .on : .off
                }
            }
        }
        else if menu == itemReprMenu {
            let useAlt: Bool = UserDefaults.standard[.useAlternativeAreaRepresentation]
            if useAlt {
                itemReprAreaMenuItem.state = .off
                itemReprAreaAltMenuItem.state = .on
            }
            else {
                itemReprAreaMenuItem.state = .on
                itemReprAreaAltMenuItem.state = .off
            }
        }
    }
    
    fileprivate func updateColumns() {
        var hiddenValue: Bool!
        
        hiddenValue = !UserDefaults.standard[.toggleTableColumnID]
        if columnID.isHidden != hiddenValue {
            columnID.isHidden = hiddenValue
        }
        
        hiddenValue = !UserDefaults.standard[.toggleTableColumnDescription]
        if columnDescription.isHidden != hiddenValue {
            columnDescription.isHidden = hiddenValue
        }
    }
    
    fileprivate func deleteConfirmForItems(_ itemsToRemove: [ContentItem]) -> Bool {
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
        tableViewDoubleAction(tableView)
    }
    
    @IBAction func delete(_ sender: Any) {
        guard let collection = content?.items else { return }
        let rows = ((tableView.clickedRow >= 0 && !tableView.selectedRowIndexes.contains(tableView.clickedRow)) ? IndexSet(integer: tableView.clickedRow) : IndexSet(tableView.selectedRowIndexes))
            .filteredIndexSet(includeInteger: { $0 < collection.count })
        let itemsToRemove = rows.map({ collection[$0] })
        guard deleteConfirmForItems(itemsToRemove) else { return }
        internalDeleteContentItems(itemsToRemove)
        tableView.removeRows(at: rows, withAnimation: .effectFade)
    }
    
    @IBAction func copy(_ sender: Any) {
        guard let collection = content?.items else { return }
        let selectedItems = ((tableView.clickedRow >= 0 && !tableView.selectedRowIndexes.contains(tableView.clickedRow)) ? IndexSet(integer: tableView.clickedRow) : IndexSet(tableView.selectedRowIndexes))
            .filteredIndexSet(includeInteger: { $0 < collection.count })
            .map({ collection[$0] })
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
        guard tableView.clickedRow >= 0 else { return }
        guard let area = content?.items[tableView.clickedRow] as? PixelArea else { return }
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["png"]
        panel.beginSheetModal(for: view.window!) { (resp) in
            if resp == .OK {
                if let url = panel.url {
                    self.saveCroppedImage(of: area, to: url)
                }
            }
        }
    }
    
    fileprivate func saveCroppedImage(of area: PixelArea, to url: URL) {
        guard let data = screenshot?.image?.pngRepresentation(of: area) else { return }
        do {
            try data.write(to: url)
        }
        catch {
            presentError(error)
        }
    }
    
    @IBAction func exportAs(_ sender: Any) {
        guard let collection = content?.items else { return }
        let selectedItems = ((tableView.clickedRow >= 0 && !tableView.selectedRowIndexes.contains(tableView.clickedRow)) ? IndexSet(integer: tableView.clickedRow) : IndexSet(tableView.selectedRowIndexes))
            .filteredIndexSet(includeInteger: { $0 < collection.count })
            .map({ collection[$0] })
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
    
    fileprivate func exportItems(_ items: [ContentItem], to url: URL) {
        do {
            try screenshot?.export.exportItems(items, to: url)
        }
        catch {
            presentError(error)
        }
    }
    
    @IBAction func toggleHeader(_ sender: NSMenuItem) {
        var defaultKey: UserDefaults.Key?
        if sender.identifier == .toggleTableColumnID {
            defaultKey = .toggleTableColumnID
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
        if sender == itemReprAreaMenuItem {
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
        guard let targetIndex = (tableView.clickedRow >= 0 && !tableView.selectedRowIndexes.contains(tableView.clickedRow)) ? tableView.clickedRow : tableView.selectedRowIndexes.first else { return }
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
    
}

extension ContentController: NSTableViewDelegate, NSTableViewDataSource {
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let collection = content?.items else { return }
        let selectedItems = tableView.selectedRowIndexes
            .filteredIndexSet(includeInteger: { $0 < collection.count })
            .map({ collection[$0] })
        actionDelegate.contentActionSelected(selectedItems)
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
            if col == .columnID {
                cell.textField?.stringValue = String(item.id)
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

