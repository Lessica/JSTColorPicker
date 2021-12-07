//
//  BrowserViewController.swift
//  JSTColorPicker
//
//  Created by Rachel on 12/6/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa


// MIT licence. Copyright © 2018 Simon Strandgaard. All rights reserved.
import Foundation

private extension URL {
    /// SwiftyRelativePath: Creates a path between two paths
    ///
    ///     let u1 = URL(fileURLWithPath: "/Users/Mozart/Music/Nachtmusik.mp3")!
    ///     let u2 = URL(fileURLWithPath: "/Users/Mozart/Documents")!
    ///     u1.relativePath(from: u2)  // "../Music/Nachtmusik.mp3"
    ///
    /// Case (in)sensitivity is not handled.
    ///
    /// It is assumed that given URLs are absolute. Not relative.
    ///
    /// This method doesn't access the filesystem. It assumes no symlinks.
    ///
    /// `"."` and `".."` in the given URLs are removed.
    ///
    /// - Parameter base: The `base` url must be an absolute path to a directory.
    ///
    /// - Returns: The returned path is relative to the `base` path.
    ///
    func relativePath(from base: URL) -> String? {
        // Original code written by Martin R. https://stackoverflow.com/a/48360631/78336
        // Ensure that both URLs represent files
        guard self.isFileURL && base.isFileURL else {
            return nil
        }
        
        // Ensure that it's absolute paths. Ignore relative paths.
        guard self.baseURL == nil && base.baseURL == nil else {
            return nil
        }
        
        // Remove/replace "." and "..", make paths absolute
        let destComponents = self.standardizedFileURL.pathComponents
        let baseComponents = base.standardizedFileURL.pathComponents
        
        // Find number of common path components
        var i = 0
        while i < destComponents.count && i < baseComponents.count
                && destComponents[i] == baseComponents[i] {
            i += 1
        }
        
        // Build relative path
        var relComponents = Array(repeating: "..", count: baseComponents.count - i)
        relComponents.append(contentsOf: destComponents[i...])
        return relComponents.joined(separator: "/")
    }
}


private extension NSUserInterfaceItemIdentifier {
    private static let sortedByPrefix     = "com.jst.JSTColorPicker.Panel.Browser.SortedBy."
    
    static let sortedByName               = Self(Self.sortedByPrefix + "Name"            )
    static let sortedByKind               = Self(Self.sortedByPrefix + "Kind"            )
    static let sortedByDateLastOpened     = Self(Self.sortedByPrefix + "DateLastOpened"  )
    static let sortedByDateAdded          = Self(Self.sortedByPrefix + "DateAdded"       )
    static let sortedByDateModified       = Self(Self.sortedByPrefix + "DateModified"    )
    static let sortedByDateCreated        = Self(Self.sortedByPrefix + "DateCreated"     )
    static let sortedBySize               = Self(Self.sortedByPrefix + "Size"            )
    static let _sortedByOptions           : [NSUserInterfaceItemIdentifier] = [
        .sortedByName,
        .sortedByKind,
        .sortedByDateLastOpened,
        .sortedByDateAdded,
        .sortedByDateModified,
        .sortedByDateCreated,
        .sortedBySize,
    ]
}


class BrowserViewController: NSViewController, NSMenuDelegate, NSMenuItemValidation {
    
    @IBOutlet weak var browserController: BrowserController!
    @IBOutlet weak var browser: NSBrowser!
    @IBOutlet weak var contextMenu: NSMenu!
    @IBOutlet weak var sortedByMenu: NSMenu!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let defaultPath: String = UserDefaults.standard[.screenshotSavingPath] {
            setURL(URL(
                fileURLWithPath: NSString(string: defaultPath).expandingTildeInPath
            ))
        }
    }
    
    @discardableResult
    func setURL(_ url: URL) -> Bool {
        guard let rootNode = self.browserController.rootItem(for: self.browser) as? FileSystemNode else {
            return false
        }
        let expandedRelativePath = URL(string: "/")!.appendingPathComponent(
            url.relativePath(
                from: rootNode.url
            ) ?? ""
        ).path
        return self.browser.setPath(expandedRelativePath)
    }
    
    private var actionSelectedRowIndex: Int? {
        (browser.clickedRow >= 0 && !(browser.selectedRowIndexes(inColumn: browser.clickedColumn) ?? IndexSet()).contains(browser.clickedRow)) ? browser.clickedRow : browser.selectedRowIndexes(inColumn: browser.clickedColumn)?.first
    }
    
    private var actionSelectedRowIndexes: IndexSet {
        (browser.clickedRow >= 0 && !(browser.selectedRowIndexes(inColumn: browser.clickedColumn) ?? IndexSet()).contains(browser.clickedRow))
        ? IndexSet(integer: browser.clickedRow)
        : IndexSet(browser.selectedRowIndexes(inColumn: browser.clickedColumn) ?? IndexSet())
    }
    
    private var hasSelectedNode: Bool { actionSelectedRowIndexes.count > 0 }
    private var selectedNodes: [FileSystemNode] {
        guard let parentNode = browser.parentForItems(inColumn: browser.clickedColumn) as? FileSystemNode,
              let collection = parentNode.children
        else {
            return []
        }
        return actionSelectedRowIndexes.map { collection[$0] }
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(showInFinder(_:)) ||
            menuItem.action == #selector(openInTab(_:)) ||
            menuItem.action == #selector(openWithExternalEditor(_:)) ||
            menuItem.action == #selector(moveToTrash(_:)) ||
            menuItem.action == #selector(duplicate(_:))
        {
            return browser.clickedRow >= 0
        }
        else if menuItem.action == #selector(rename(_:))
        {
            return browser.clickedRow >= 0 && actionSelectedRowIndexes.count == 1
        }
        else if menuItem.action == #selector(newFolder(_:)) ||
                    menuItem.action == #selector(sortBy(_:))
        {
            return browser.clickedColumn >= 0
        }
        return false
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu == self.sortedByMenu {
            for menuItem in menu.items {
                if let menuItemIdentifier = menuItem.identifier?.rawValue,
                   let menuItemIdentifierIndex = NSUserInterfaceItemIdentifier._sortedByOptions.map({ $0.rawValue }).firstIndex(of: menuItemIdentifier),
                   browserController.sortedBy.rawValue == UInt(menuItemIdentifierIndex)
                {
                    menuItem.state = .on
                } else {
                    menuItem.state = .off
                }
            }
        }
    }
    
    @IBAction func showInFinder(_ sender: Any?) {
        NSWorkspace.shared.activateFileViewerSelecting(selectedNodes.compactMap({ $0.url }))
    }
    
    @IBAction func openInTab(_ sender: Any?) {
        selectedNodes.forEach { [unowned self] node in
            self.browserController.openInternalNode(node)
        }
    }
    
    @IBAction func openWithExternalEditor(_ sender: Any?) {
        selectedNodes.forEach { [unowned self] node in
            self.browserController.openExternalNode(node)
        }
    }
    
    private func reloadClickedColumn() {
        if let parentNode = browser.parentForItems(inColumn: browser.clickedColumn) as? FileSystemNode {
            parentNode.invalidateChildren()
        }
        browser.reloadColumn(browser.clickedColumn)
    }
    
    @IBAction func moveToTrash(_ sender: Any?) {
        selectedNodes.forEach { node in
            try? FileManager.default.trashItem(at: node.url, resultingItemURL: nil)
        }
        reloadClickedColumn()
    }
    
    @IBAction func rename(_ sender: Any?) {
        fatalError("not implemented")
    }
    
    @IBAction func duplicate(_ sender: Any?) {
        NSWorkspace.shared.duplicate(selectedNodes.compactMap({ $0.url })) { [weak self] _, err in
            // TODO: select newly created items
            if let err = err {
                self?.presentError(err)
            }
            self?.reloadClickedColumn()
        }
    }
    
    @IBAction func newFolder(_ sender: Any?) {
        fatalError("not implemented")
    }
    
    @IBAction func sortBy(_ sender: Any?) {
        if let menuItem = sender as? NSMenuItem,
           let menuItemIdentifier = menuItem.identifier?.rawValue,
           let menuItemIdentifierIndex = NSUserInterfaceItemIdentifier._sortedByOptions.map({ $0.rawValue }).firstIndex(of: menuItemIdentifier),
           let rootNode = browserController.rootItem(for: browser) as? FileSystemNode
        {
            rootNode.setChildrenSortedBy(FileSystemNodeSortedBy(rawValue: UInt(menuItemIdentifierIndex)))
            rootNode.invalidateChildren()
        }
        reloadClickedColumn()
    }
    
}
