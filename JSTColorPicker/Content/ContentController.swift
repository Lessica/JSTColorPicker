//
//  ContentController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/21/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

extension NSUserInterfaceItemIdentifier {
    static let columnID = NSUserInterfaceItemIdentifier("col-id")
    static let columnSimilarity = NSUserInterfaceItemIdentifier("col-similarity")
    static let columnDescription = NSUserInterfaceItemIdentifier("col-desc")
}

extension NSUserInterfaceItemIdentifier {
    static let cellID = NSUserInterfaceItemIdentifier("cell-id")
    static let cellSimilarity = NSUserInterfaceItemIdentifier("cell-similarity")
    static let cellDescription = NSUserInterfaceItemIdentifier("cell-desc")
}

enum ContentError: LocalizedError {
    case itemExists(item: CustomStringConvertible)
    case itemDoesNotExist(item: CustomStringConvertible)
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
    
    weak var actionDelegate: ContentActionDelegate?
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
    fileprivate var nextSimilarity: Double {
        if let lastSimilarity = content?.items.last?.similarity {
            return lastSimilarity
        }
        return 1.0
    }
    fileprivate var undoToken: NotificationToken?
    fileprivate var redoToken: NotificationToken?
    
    @IBOutlet weak var tableView: ContentTableView!
    @IBOutlet weak var addCoordinateButton: NSButton!
    @IBOutlet weak var addCoordinateField: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        initializeController()
        
        tableView.tableViewResponder = self
        undoToken = NotificationCenter.default.observe(name: NSNotification.Name.NSUndoManagerDidUndoChange, object: undoManager) { [unowned self] (notification) in
            self.tableView.reloadData()
        }
        redoToken = NotificationCenter.default.observe(name: NSNotification.Name.NSUndoManagerDidRedoChange, object: undoManager) { [unowned self] (notification) in
            self.tableView.reloadData()
        }
    }
    
    override func willPresentError(_ error: Error) -> Error {
        let error = super.willPresentError(error)
        debugPrint(error.localizedDescription)
        return error
    }
    
    @IBAction func similarityFieldChanged(_ sender: NSTextField) {
        guard let content = content else { return }
        let row = tableView.row(for: sender)
        assert(row >= 0 && row < content.items.count)
        let value = sender.doubleValue
        if value >= 1 && value <= 100 {
            let item = content.items[row].copy() as! ContentItem
            item.similarity = min(max(sender.doubleValue / 100.0, 0.01), 1.0)
            internalUpdateContentItems([item])
        }
        let similarity = String(Int(content.items[row].similarity * 100.0))
        sender.stringValue = similarity
    }
    
    @IBAction func addCoordinateFieldChanged(_ sender: NSTextField) {
        guard let image = screenshot?.image else { return }
        
        let size = image.size
        let scanner = Scanner(string: sender.stringValue)
        scanner.charactersToBeSkipped = CharacterSet.alphanumerics.inverted
        
        var x = Int.max
        var y = Int.max
        var x2 = Int.max
        var y2 = Int.max
        
        scanner.scanInt(&x)
        scanner.scanInt(&y)
        scanner.scanInt(&x2)
        scanner.scanInt(&y2)
        
        guard x >= 0 && y >= 0 && x < size.width && y < size.height else { return }
        if x2 >= 0 && y2 >= 0 && x2 < size.width && y2 < size.height {
            let rect = PixelRect(coordinate1: PixelCoordinate(x: x, y: y), coordinate2: PixelCoordinate(x: x2, y: y2))
            
            do {
                if let item = try addContentItem(of: rect) {
                    if let _ = try selectContentItem(item) {
                        sender.stringValue = ""
                        makeFirstResponder(tableView)
                    }
                }
            }
            catch ContentError.itemExists {
                do {
                    if let _ = try selectContentItem(of: rect) {
                        sender.stringValue = ""
                        makeFirstResponder(tableView)
                    }
                }
                catch let error {
                    presentError(error)
                }
            }
            catch let error {
                presentError(error)
            }
        } else {
            let coordinate = PixelCoordinate(x: x, y: y)
            
            do {
                if let item = try addContentItem(of: coordinate) {
                    if let _ = try selectContentItem(item) {
                        sender.stringValue = ""
                        makeFirstResponder(tableView)
                    }
                }
            }
            catch ContentError.itemExists {
                do {
                    if let _ = try selectContentItem(of: coordinate) {
                        sender.stringValue = ""
                        makeFirstResponder(tableView)
                    }
                }
                catch let error {
                    presentError(error)
                }
            }
            catch let error {
                presentError(error)
            }
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
        undoManager?.registerUndo(withTarget: self, handler: { targetSelf in
            targetSelf.internalDeleteContentItems(items)  // memory captured and managed by UndoManager
        })
        actionDelegate?.contentActionAdded(items)
        items.forEach { (item) in
            let idx = content.items.insertionIndexOf(item, isOrderedBefore: { $0 < $1 })
            content.items.insert(item, at: idx)
        }
    }
    
    fileprivate func internalDeleteContentItems(_ items: [ContentItem]) {
        guard let content = content else { return }
        undoManager?.registerUndo(withTarget: self, handler: { (targetSelf) in
            targetSelf.internalAddContentItems(items)  // memory captured and managed by UndoManager
        })
        actionDelegate?.contentActionDeleted(items)
        content.items.removeAll(where: { items.contains($0) })
    }
    
    fileprivate func internalUpdateContentItems(_ items: [ContentItem]) {
        guard let content = content else { return }
        let itemIDs = items.compactMap({ $0.id })
        let itemToRemove = content.items.filter({ itemIDs.contains($0.id) })
        undoManager?.registerUndo(withTarget: self, handler: { (targetSelf) in
            targetSelf.internalUpdateContentItems(itemToRemove)  // memory captured and managed by UndoManager
        })
        actionDelegate?.contentActionUpdated(items)
        content.items.removeAll(where: { itemIDs.contains($0.id) })
        items.forEach { (item) in
            let idx = content.items.insertionIndexOf(item, isOrderedBefore: { $0 < $1 })
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
        item.similarity = nextSimilarity
        internalAddContentItems([item])
        tableView.reloadData()
        
        return try selectContentItem(item)
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
                relatedItem.similarity = item.similarity
                relatedItems.append(relatedItem)
                beginID += 1
            }
        }
        internalAddContentItems(relatedItems)
        tableView.reloadData()
        
        selectContentItems(in: IndexSet(integersIn: beginRows..<beginRows + relatedItems.count))
        return relatedItems
    }
    
    fileprivate func selectContentItem(of coordinate: PixelCoordinate) throws -> ContentItem? {
        guard let image = screenshot?.image else { throw ContentError.noDocumentLoaded }
        guard let color = image.color(at: coordinate) else { throw ContentError.itemOutOfRange(item: coordinate, range: image.size) }
        return try selectContentItem(color)
    }
    
    fileprivate func selectContentItem(of rect: PixelRect) throws -> ContentItem? {
        guard let image = screenshot?.image else { throw ContentError.noDocumentLoaded }
        guard let area = image.area(at: rect) else { throw ContentError.itemOutOfRange(item: rect, range: image.size) }
        return try selectContentItem(area)
    }
    
    func selectContentItem(_ item: ContentItem?) throws -> ContentItem? {
        if let item = item {
            guard let content = content else { throw ContentError.noDocumentLoaded }
            guard let itemIndex = content.items.firstIndex(of: item) else { throw ContentError.itemDoesNotExist(item: item) }
            tableView.selectRowIndexes(IndexSet(integer: itemIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(itemIndex)
        }
        else {
            tableView.deselectAll(nil)
        }
        return item
    }
    
    fileprivate func selectContentItems(in set: IndexSet) {
        if !set.isEmpty, let lastIndex = set.last {
            tableView.selectRowIndexes(set, byExtendingSelection: false)
            tableView.scrollRowToVisible(lastIndex)
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
        
        color.id = item.id
        return try updateContentItem(color)
    }
    
    func updateContentItem(_ item: ContentItem, to rect: PixelRect) throws -> ContentItem? {
        guard let content = content else { throw ContentError.noDocumentLoaded }
        guard content.items.first(where: { $0 == item }) != nil else { throw ContentError.itemDoesNotExist(item: item) }
        guard content.lazyAreas.first(where: { $0.rect == rect }) == nil else { throw ContentError.itemConflict(item1: rect, item2: item) }
        guard let image = screenshot?.image else { throw ContentError.noDocumentLoaded }
        guard let area = image.area(at: rect) else { throw ContentError.itemOutOfRange(item: rect, range: image.size) }
        
        area.id = item.id
        return try updateContentItem(area)
    }
    
    private func updateContentItem(_ item: ContentItem) throws -> ContentItem? {
        internalUpdateContentItems([item])
        tableView.reloadData()
        return try selectContentItem(item)
    }
    
}

extension ContentController: ContentTableViewResponder {
    
    @IBAction func tableViewAction(_ sender: ContentTableView) {
        // replaced by -tableViewSelectionDidChange(_:)
    }
    
    @IBAction func tableViewDoubleAction(_ sender: ContentTableView) {
        guard let delegate = actionDelegate else { return }
        guard let collection = content?.items else { return }
        let selectedItems = (tableView.clickedRow >= 0 ? IndexSet(integer: tableView.clickedRow) : IndexSet(tableView.selectedRowIndexes))
            .filteredIndexSet(includeInteger: { $0 < collection.count })
            .map({ collection[$0] })
        delegate.contentActionConfirmed(selectedItems)
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
        else if item.action == #selector(saveAs(_:)) {
            guard tableView.clickedRow >= 0 else { return false }
            if tableView.selectedRowIndexes.count > 1 && tableView.selectedRowIndexes.contains(tableView.clickedRow) { return false }
            if let _ = content.items[tableView.clickedRow] as? PixelArea { return true }
        }
        else if item.action == #selector(paste(_:)) {
            return screenshot?.export.canImportFromAdditionalPasteboard ?? false
        }
        return false
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        
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
        catch let error {
            presentError(error)
        }
    }
    
    @IBAction func paste(_ sender: Any) {
        guard let items = screenshot?.export.importFromAdditionalPasteboard() else { return }
        do {
            try importContentItems(items)
        } catch let error {
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
        catch let error {
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
        catch let error {
            presentError(error)
        }
    }
    
    fileprivate func exportItems(_ items: [ContentItem], to url: URL) {
        do {
            try screenshot?.export.exportItems(items, to: url)
        }
        catch let error {
            presentError(error)
        }
    }
    
}

extension ContentController: NSTableViewDelegate, NSTableViewDataSource {
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let delegate = actionDelegate else { return }
        guard let collection = content?.items else { return }
        let selectedItems = tableView.selectedRowIndexes
            .filteredIndexSet(includeInteger: { $0 < collection.count })
            .map({ collection[$0] })
        delegate.contentActionSelected(selectedItems)
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
            else if col == .columnSimilarity {
                let similarity = String(Int(item.similarity * 100.0))
                cell.textField?.toolTip = """
                Similarity: \(similarity)%
                Click here to edit.
                """
                cell.textField?.stringValue = similarity
            }
            else if col == .columnDescription {
                if let color = item as? PixelColor {
                    cell.imageView?.image = NSImage(color: color.pixelColorRep.toNSColor(), size: NSSize(width: 14, height: 14))
                    cell.textField?.toolTip = """
                    Location: \(color.coordinate)
                    CSS: \(color.cssString)
                    RGBA: \(color.cssRGBAString)
                    """
                }
                else if let area = item as? PixelArea {
                    cell.imageView?.image = NSImage(named: "JSTCropSmall")
                    cell.textField?.toolTip = """
                    Origin: \(area.rect.origin)
                    Opposite: \(area.rect.opposite)
                    Size: \(area.rect.size)
                    """
                }
                cell.textField?.stringValue = item.description
            }
            return cell
        }
        return nil
    }
    
}

extension ContentController: ScreenshotLoader {
    
    func initializeController() {
        self.screenshot = nil
        addCoordinateButton.isEnabled = false
        addCoordinateField.isEnabled = false
        tableView.reloadData()
    }
    
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
