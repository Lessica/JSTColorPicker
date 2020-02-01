//
//  ContentController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/21/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

enum ContentColumnIdentifier: String {
    case id = "col-id"
    case color = "col-color"
    case coordinate = "col-coordinate"
}

enum ContentCellIdentifier: String {
    case id = "cell-id"
    case color = "cell-color"
    case coordinate = "cell-coordinate"
}

enum ContentError: LocalizedError {
    case exists
    case reachLimit
    case noDocument
    
    var failureReason: String? {
        switch self {
        case .exists:
            return "This coordinate already exists."
        case .reachLimit:
            return "Maximum pixel count reached."
        case .noDocument:
            return "No document loaded."
        }
    }
}

protocol ContentActionDelegate: class {
    func contentActionAdded(_ items: [PixelColor], by controller: ContentController)
    func contentActionSelected(_ items: [PixelColor], by controller: ContentController)
    func contentActionConfirmed(_ items: [PixelColor], by controller: ContentController)
    func contentActionDeleted(_ items: [PixelColor], by controller: ContentController)
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
    
    fileprivate func addContentItems(_ items: [PixelColor]) {
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
    
    fileprivate func deleteContentItems(_ items: [PixelColor]) {
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
        var selectedItems: [PixelColor] = []
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
        if item.action == #selector(delete(_:)) {
            let idxs = tableView.selectedRowIndexes
            return idxs.count > 0
        }
        return false
    }
    
    func submitItem(point: CGPoint, color: JSTPixelColor) throws -> PixelColor {
        guard let content = content else {
            throw ContentError.noDocument
        }
        if content.items.count >= Content.maximumCount {
            throw ContentError.reachLimit
        }
        let coordinate = PixelCoordinate(point)
        if content.items.first(where: { $0.coordinate.x == coordinate.x && $0.coordinate.y == coordinate.y }) != nil {
            throw ContentError.exists
        }
        let item = PixelColor(id: nextID, coordinate: coordinate, color: color)
        addContentItems([item])
        tableView.reloadData()
        return item
    }
    
    @IBAction func delete(_ sender: Any) {
        guard let content = content else { return }
        let collection = content.items
        let rows = IndexSet(tableView.selectedRowIndexes.filter({ $0 < collection.count }))
        var selectedItems: [PixelColor] = []
        for row in rows {
            selectedItems.append(collection[row])
        }
        deleteContentItems(selectedItems)
        tableView.removeRows(at: rows, withAnimation: .effectFade)
    }
    
}

extension ContentController: NSTableViewDelegate, NSTableViewDataSource {
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let delegate = actionDelegate else { return }
        guard let collection = content?.items else { return }
        let rows = tableView.selectedRowIndexes
        var selectedItems: [PixelColor] = []
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
            let col = tableColumn.identifier.rawValue
            let pixel = content.items[row]
            if col == ContentColumnIdentifier.id.rawValue {
                cell.textField?.stringValue = String(pixel.id)
            }
            else if col == ContentColumnIdentifier.color.rawValue {
                cell.imageView?.image = NSImage(color: pixel.pixelColorRep.toNSColor(), size: NSSize(width: 12, height: 12))
                cell.textField?.stringValue = pixel.pixelColorRep.cssString
            }
            else if col == ContentColumnIdentifier.coordinate.rawValue {
                cell.textField?.stringValue = "(\(pixel.coordinate.x),\(pixel.coordinate.y))"
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
