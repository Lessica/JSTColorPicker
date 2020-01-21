//
//  ContentController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/21/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

enum ContentColumnIdentifier: String {
    case color = "col-color"
    case coordinate = "col-coordinate"
}

enum ContentCellIdentifier: String {
    case color = "cell-color"
    case coordinate = "cell-coordinate"
}

enum ContentError: LocalizedError {
    case exists
    case reachLimit
    
    var failureReason: String? {
        switch self {
        case .exists:
            return "This coordinate already exists."
        case .reachLimit:
            return "Maximum pixel count reached."
        }
    }
}

class ContentController: NSViewController {
    
    let content = Content()
    @IBOutlet weak var tableView: NSTableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
}

extension Array {
    mutating func remove(at set:IndexSet) {
        var arr = Swift.Array(self.enumerated())
        arr.removeAll{ set.contains($0.offset) }
        self = arr.map{ $0.element }
    }
}

extension ContentController: NSUserInterfaceValidations {
    
    func submitContent(point: CGPoint, color: JSTPixelColor) throws -> PixelColor {
        if content.pixelColorCollection.count >= Content.maximumPixelCount {
            throw ContentError.reachLimit
        }
        let coordinate = PixelCoordinate(point)
        if content.pixelColorCollection.first(where: { $0.coordinate.x == coordinate.x && $0.coordinate.y == coordinate.y }) != nil {
            throw ContentError.exists
        }
        let pixel = PixelColor(coordinate: coordinate, color: color)
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
        let idxs = tableView.selectedRowIndexes
        content.pixelColorCollection.remove(at: idxs)
        tableView.removeRows(at: idxs, withAnimation: .effectFade)
    }
    
}

extension ContentController: NSTableViewDelegate {
    
}

extension ContentController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return content.pixelColorCollection.count
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 20
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn else { return nil }
        if let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as? NSTableCellView {
            let col = tableColumn.identifier.rawValue
            let pixel = content.pixelColorCollection[row]
            if col == ContentColumnIdentifier.color.rawValue {
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
