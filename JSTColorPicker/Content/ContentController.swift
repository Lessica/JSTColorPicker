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
    case itemExists
    case itemDoesNotExist
    case itemOutOfRange
    case itemReachLimit
    case itemConflict
    case noDocumentLoaded
    
    var failureReason: String? {
        switch self {
        case .itemExists:
            return "This item already exists."
        case .itemDoesNotExist:
            return "This item does not exist."
        case .itemOutOfRange:
            return "The requested item is out of the document range."
        case .itemReachLimit:
            return "Maximum item count reached."
        case .itemConflict:
            return "The requested item conflicts with another item in the document."
        case .noDocumentLoaded:
            return "No document loaded."
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
        if let content = content {
            if let maxID = content.items.last?.id {
                return maxID + 1
            }
        }
        return 1
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
    
    @IBAction func similarityFieldChanged(_ sender: NSTextField) {
        guard let content = content else { return }
        let row = tableView.row(for: sender)
        guard row >= 0 && row < content.items.count else { return }
        let value = sender.doubleValue
        if value >= 1 && value <= 100 {
            content.items[row].similarity = min(max(sender.doubleValue / 100.0, 0.01), 1.0)
        }
        sender.stringValue = String(format: "%.2f", content.items[row].similarity * 100.0)
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

extension Array {
    func insertionIndexOf(_ elem: Element, isOrderedBefore: (Element, Element) -> Bool) -> Int {
        var lo = 0
        var hi = self.count - 1
        while lo <= hi {
            let mid = (lo + hi) / 2
            if isOrderedBefore(self[mid], elem) {
                lo = mid + 1
            } else if isOrderedBefore(elem, self[mid]) {
                hi = mid - 1
            } else {
                return mid // found at position mid
            }
        }
        return lo // not found, would be inserted at position lo
    }
    mutating func remove(at set: IndexSet) {
        var arr = Swift.Array(self.enumerated())
        arr.removeAll { set.contains($0.offset) }
        self = arr.map { $0.element }
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
        guard let color = image.color(at: coordinate) else { throw ContentError.itemOutOfRange }
        return try addContentItem(color)
    }
    
    func addContentItem(of rect: PixelRect) throws -> ContentItem? {
        guard let image = screenshot?.image else { throw ContentError.noDocumentLoaded }
        guard let area = image.area(at: rect) else { throw ContentError.itemOutOfRange }
        return try addContentItem(area)
    }
    
    private func addContentItem(_ item: ContentItem) throws -> ContentItem? {
        guard let content = content else { throw ContentError.noDocumentLoaded }
        guard content.items.count < Content.maximumCount else { throw ContentError.itemReachLimit }
        guard content.items.first(where: { $0 == item }) == nil else { throw ContentError.itemExists }
        
        item.id = nextID
        internalAddContentItems([item])
        tableView.reloadData()
        
        let numberOfRows = tableView.numberOfRows
        if numberOfRows > 0 {
            tableView.scrollRowToVisible(numberOfRows - 1)
        }
        
        return item
    }
    
    func selectContentItem(of coordinate: PixelCoordinate) throws -> ContentItem? {
        guard let image = screenshot?.image else { throw ContentError.noDocumentLoaded }
        guard let color = image.color(at: coordinate) else { throw ContentError.itemOutOfRange }
        return try selectContentItem(color)
    }
    
    func selectContentItem(of rect: PixelRect) throws -> ContentItem? {
        guard let image = screenshot?.image else { throw ContentError.noDocumentLoaded }
        guard let area = image.area(at: rect) else { throw ContentError.itemOutOfRange }
        return try selectContentItem(area)
    }
    
    func selectContentItem(_ item: ContentItem) throws -> ContentItem? {
        guard let content = content else { throw ContentError.noDocumentLoaded }
        guard let itemIndex = content.items.firstIndex(of: item) else { throw ContentError.itemDoesNotExist }
        tableView.selectRowIndexes(IndexSet(integer: itemIndex), byExtendingSelection: false)
        return item
    }
    
    func deleteContentItem(of coordinate: PixelCoordinate) throws -> ContentItem? {
        guard let content = content else { throw ContentError.noDocumentLoaded }
        var optItem: ContentItem?
        if let color = content.colors.reversed().first(where: { $0.coordinate == coordinate }) {
            optItem = color
        }
        else if let area = content.areas.reversed().first(where: { $0.rect.contains(coordinate) }) {
            optItem = area
        }
        guard let item = optItem else { throw ContentError.itemDoesNotExist }
        return try deleteContentItem(item)
    }
    
    func deleteContentItem(_ item: ContentItem) throws -> ContentItem? {
        guard let content = content else { throw ContentError.noDocumentLoaded }
        guard let itemIndex = content.items.firstIndex(of: item) else { throw ContentError.itemDoesNotExist }
        internalDeleteContentItems([item])
        tableView.removeRows(at: IndexSet(integer: itemIndex), withAnimation: .effectFade)
        return item
    }
    
    func updateContentItem(_ item: ContentItem, to coordinate: PixelCoordinate) throws -> ContentItem? {
        guard let content = content else { throw ContentError.noDocumentLoaded }
        guard content.items.first(where: { $0 == item }) != nil else { throw ContentError.itemDoesNotExist }
        guard content.colors.first(where: { $0.coordinate == coordinate }) == nil else { throw ContentError.itemConflict }
        guard let image = screenshot?.image else { throw ContentError.noDocumentLoaded }
        guard let color = image.color(at: coordinate) else { throw ContentError.itemOutOfRange }
        
        color.id = item.id
        return try updateContentItem(color)
    }
    
    func updateContentItem(_ item: ContentItem, to rect: PixelRect) throws -> ContentItem? {
        guard let content = content else { throw ContentError.noDocumentLoaded }
        guard content.items.first(where: { $0 == item }) != nil else { throw ContentError.itemDoesNotExist }
        guard content.areas.first(where: { $0.rect == rect }) == nil else { throw ContentError.itemConflict }
        guard let image = screenshot?.image else { throw ContentError.noDocumentLoaded }
        guard let area = image.area(at: rect) else { throw ContentError.itemOutOfRange }
        
        area.id = item.id
        return try updateContentItem(area)
    }
    
    private func updateContentItem(_ item: ContentItem) throws -> ContentItem? {
        internalUpdateContentItems([item])
        tableView.reloadData()
        return item
    }
    
}

extension ContentController: ContentTableViewResponder {
    
    @IBAction func tableViewAction(_ sender: ContentTableView) {
        // replaced by -tableViewSelectionDidChange(_:)
    }
    
    @IBAction func tableViewDoubleAction(_ sender: ContentTableView) {
        guard let delegate = actionDelegate else { return }
        guard let collection = content?.items else { return }
        let rows = tableView.selectedRowIndexes
        var selectedItems: [ContentItem] = []
        rows.forEach { (row) in
            if row >= 0 && row < collection.count {
                selectedItems.append(collection[row])
            }
        }
        delegate.contentActionConfirmed(selectedItems)
    }
    
}

extension ContentController: NSUserInterfaceValidations {
    
    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(delete(_:)) || item.action == #selector(copy(_:))  {
            let idxs = tableView.selectedRowIndexes
            return idxs.count > 0
        }
        return false
    }
    
    @IBAction func delete(_ sender: Any) {
        guard let content = content else { return }
        let collection = content.items
        let rows = IndexSet(tableView.selectedRowIndexes.filter({ $0 < collection.count }))
        var selectedItems: [ContentItem] = []
        for row in rows {
            selectedItems.append(collection[row])
        }
        internalDeleteContentItems(selectedItems)
        tableView.removeRows(at: rows, withAnimation: .effectFade)
    }
    
    @IBAction func copy(_ sender: Any) {
        guard let content = content else { return }
        let collection = content.items
        let rows = IndexSet(tableView.selectedRowIndexes.filter({ $0 < collection.count }))
        var selectedItems: [ContentItem] = []
        for row in rows {
            selectedItems.append(collection[row])
        }
        if (selectedItems.count == 1) {
            screenshot?.export.copyContentItem(selectedItems.first!)
        } else {
            screenshot?.export.copyContentItems(selectedItems)
        }
    }
    
}

extension ContentController: NSTableViewDelegate, NSTableViewDataSource {
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let delegate = actionDelegate else { return }
        guard let collection = content?.items else { return }
        let rows = tableView.selectedRowIndexes
        var selectedItems: [ContentItem] = []
        rows.forEach { (row) in
            if row >= 0 && row < collection.count {
                selectedItems.append(collection[row])
            }
        }
        delegate.contentActionSelected(selectedItems)
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        guard let content = content else { return 0 }
        return content.items.count
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
                cell.textField?.stringValue = String(format: "%.2f", item.similarity * 100.0)
            }
            else if col == .columnDescription {
                if let item = item as? PixelColor {
                    cell.imageView?.image = NSImage(color: item.pixelColorRep.toNSColor(), size: NSSize(width: 14, height: 14))
                }
                else if let _ = item as? PixelArea {
                    cell.imageView?.image = NSImage(named: "JSTCropSmall")
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
