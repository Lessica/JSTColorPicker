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

class ContentController: NSViewController {
    
    internal weak var screenshot: Screenshot?
    fileprivate var content: Content? {
        return screenshot?.content
    }
    fileprivate var nextID: Int {
        if let content = content {
            if let maxID = content.pixelColorCollection.last?.id {
                return maxID + 1
            }
        }
        return 1
    }
    
    @IBOutlet weak var tableView: NSTableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
}

extension Array {
    mutating func remove(at set:IndexSet) {
        var arr = Swift.Array(self.enumerated())
        arr.removeAll { set.contains($0.offset) }
        self = arr.map { $0.element }
    }
}

extension ContentController: NSUserInterfaceValidations {
    
    func submitContent(point: CGPoint, color: JSTPixelColor) throws -> PixelColor {
        guard let content = content else {
            throw ContentError.noDocument
        }
        if content.pixelColorCollection.count >= Content.maximumPixelCount {
            throw ContentError.reachLimit
        }
        let coordinate = PixelCoordinate(point)
        if content.pixelColorCollection.first(where: { $0.coordinate.x == coordinate.x && $0.coordinate.y == coordinate.y }) != nil {
            throw ContentError.exists
        }
        let pixel = PixelColor(id: nextID, coordinate: coordinate, color: color)
        content.pixelColorCollection.append(pixel)
        tableView.reloadData()
        return pixel
    }
    
    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(delete(_:)) {
            let idxs = tableView.selectedRowIndexes
            return idxs.count > 0
        }
        return false
    }
    
    @IBAction func delete(_ sender: Any) {
        guard let content = content else { return }
        let idxs = tableView.selectedRowIndexes
        content.pixelColorCollection.remove(at: idxs)
        tableView.removeRows(at: idxs, withAnimation: .effectFade)
    }
    
}

extension ContentController: NSTableViewDelegate {
    
}

extension ContentController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        guard let content = content else { return 0 }
        return content.pixelColorCollection.count
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 20
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let content = content else { return nil }
        guard let tableColumn = tableColumn else { return nil }
        if let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as? NSTableCellView {
            let col = tableColumn.identifier.rawValue
            let pixel = content.pixelColorCollection[row]
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
    
    func load(screenshot: Screenshot) throws {
        guard let _ = screenshot.content else {
            throw ScreenshotError.invalidContent
        }
        self.screenshot = screenshot
        tableView.reloadData()
    }
    
}
