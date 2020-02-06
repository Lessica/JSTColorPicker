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
    static let columnDescription = NSUserInterfaceItemIdentifier("col-desc")
}

extension NSUserInterfaceItemIdentifier {
    static let cellID = NSUserInterfaceItemIdentifier("cell-id")
    static let cellDescription = NSUserInterfaceItemIdentifier("cell-desc")
}

enum ContentError: LocalizedError {
    case exists
    case doesNotExist
    case reachLimit
    case noDocument
    
    var failureReason: String? {
        switch self {
        case .exists:
            return "This item already exists."
        case .doesNotExist:
            return "This item does not exist."
        case .reachLimit:
            return "Maximum item count reached."
        case .noDocument:
            return "No document loaded."
        }
    }
}

protocol ContentActionDelegate: class {
    func contentActionAdded(_ items: [ContentItem], by controller: ContentController)
    func contentActionSelected(_ items: [ContentItem], by controller: ContentController)
    func contentActionConfirmed(_ items: [ContentItem], by controller: ContentController)
    func contentActionDeleted(_ items: [ContentItem], by controller: ContentController)
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

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        tableView.tableViewResponder = self
        undoToken = NotificationCenter.default.observe(name: NSNotification.Name.NSUndoManagerDidUndoChange, object: undoManager) { [unowned self] (notification) in
            self.tableView.reloadData()
        }
        redoToken = NotificationCenter.default.observe(name: NSNotification.Name.NSUndoManagerDidRedoChange, object: undoManager) { [unowned self] (notification) in
            self.tableView.reloadData()
        }
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
    
    fileprivate func addContentItems(_ items: [ContentItem]) {
        guard let content = content else { return }
        undoManager?.registerUndo(withTarget: self, handler: { targetSelf in
            targetSelf.deleteContentItems(items)  // memory captured and managed by UndoManager
        })
        actionDelegate?.contentActionAdded(items, by: self)
        items.forEach { (item) in
            let idx = content.items.insertionIndexOf(item, isOrderedBefore: { $0 < $1 })
            content.items.insert(item, at: idx)
        }
    }
    
    fileprivate func deleteContentItems(_ items: [ContentItem]) {
        guard let content = content else { return }
        undoManager?.registerUndo(withTarget: self, handler: { (targetSelf) in
            targetSelf.addContentItems(items)  // memory captured and managed by UndoManager
        })
        actionDelegate?.contentActionDeleted(items, by: self)
        content.items.removeAll(where: { items.contains($0) })
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
        delegate.contentActionConfirmed(selectedItems, by: self)
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
    
    func submitItem(_ item: ContentItem) throws -> ContentItem {
        guard let content = content else {
            throw ContentError.noDocument
        }
        if content.items.count >= Content.maximumCount {
            throw ContentError.reachLimit
        }
        if let item = item as? PixelColor {
            if content.colors.first(where: { $0 == item }) != nil {
                throw ContentError.exists
            }
            item.id = nextID
            addContentItems([item])
            tableView.reloadData()
            
            let numberOfRows = tableView.numberOfRows
            if numberOfRows > 0 {
                tableView.scrollRowToVisible(numberOfRows - 1)
            }
            
            return item
        }
        else if let _ = item as? PixelArea {
            // TODO: submit `PixelArea` item
        }
        return item
    }
    
    // TODO: delete `PixelArea` item
    func deleteItem(at coordinate: PixelCoordinate) throws -> PixelColor {
        guard let content = content else {
            throw ContentError.noDocument
        }
        
        if let itemIndex = (content.items.firstIndex(where: { (item) -> Bool in
            if let item = item as? PixelColor {
                if item.coordinate == coordinate {
                    return true
                }
            }
            return false
        })) {
            if let item = content.items[itemIndex] as? PixelColor {
                deleteContentItems([item])
                tableView.removeRows(at: IndexSet(integer: itemIndex), withAnimation: .effectFade)
                return item
            }
        }
        
        throw ContentError.doesNotExist
    }
    
    @IBAction func delete(_ sender: Any) {
        guard let content = content else { return }
        let collection = content.items
        let rows = IndexSet(tableView.selectedRowIndexes.filter({ $0 < collection.count }))
        var selectedItems: [ContentItem] = []
        for row in rows {
            selectedItems.append(collection[row])
        }
        deleteContentItems(selectedItems)
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
        
        // TODO: export using template
        var outputString = ""
        outputString += "{\n"
        selectedItems.forEach { (item) in
            if let item = item as? PixelColor {
                outputString += "  { \(item.coordinate.x), \(item.coordinate.y), \(item.pixelColorRep.hexString) },  -- \(item.id)\n"
            }
            else if let item = item as? PixelArea {
                // TODO: copy export from `PixelArea`
                outputString += "  -- \(item.id) (not implemented)\n"
            }
        }
        outputString += "}"
        
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(outputString, forType: .string)
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
        delegate.contentActionSelected(selectedItems, by: self)
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
            else if col == .columnDescription {
                if let item = item as? PixelColor {
                    cell.imageView?.image = NSImage(color: item.pixelColorRep.toNSColor(), size: NSSize(width: 14, height: 14))
                }
                else if let _ = item as? PixelArea {
                    // TODO: icon of `PixelArea`
                    cell.imageView?.image = NSImage()
                }
                cell.textField?.stringValue = item.description
            }
            return cell
        }
        return nil
    }
    
}

extension ContentController: ScreenshotLoader {
    
    func resetController() {
        self.screenshot = nil
        tableView.reloadData()
    }
    
    func load(_ screenshot: Screenshot) throws {
        guard let _ = screenshot.content else {
            throw ScreenshotError.invalidContent
        }
        self.screenshot = screenshot
        tableView.reloadData()
    }
    
}
