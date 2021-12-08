//
//  BrowserViewController.swift
//  JSTColorPicker
//
//  Created by Rachel on 12/6/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa
import PromiseKit


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
    
    private var hasSelectedChildNode: Bool { actionSelectedRowIndexes.count > 0 }
    private var selectedParentNode: FileSystemNode? {
        return browser.parentForItems(inColumn: browser.clickedColumn) as? FileSystemNode
    }
    private var selectedChildNodes: [FileSystemNode] {
        guard let parentNode = selectedParentNode,
              let collection = parentNode.children
        else {
            return []
        }
        if actionIsPreview {
            return [parentNode]
        }
        return actionSelectedRowIndexes.map { collection[$0] }
    }

    private var actionIsPreview: Bool {
        guard browser.clickedRow < 0,
                let parentNode = selectedParentNode
        else {
            return false
        }
        return parentNode.isPackage || !parentNode.isDirectory
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(showInFinder(_:)) ||
            menuItem.action == #selector(openInTab(_:)) ||
            menuItem.action == #selector(openWithExternalEditor(_:)) ||
            menuItem.action == #selector(moveToTrash(_:)) ||
            menuItem.action == #selector(duplicate(_:))
        {
            return actionIsPreview || browser.clickedRow >= 0
        }
        else if menuItem.action == #selector(rename(_:))
        {
            return actionIsPreview || (browser.clickedRow >= 0 && actionSelectedRowIndexes.count == 1)
        }
        else if menuItem.action == #selector(newFolder(_:)) ||
                    menuItem.action == #selector(sortBy(_:))
        {
            return !actionIsPreview && browser.clickedColumn >= 0
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
        NSWorkspace.shared.activateFileViewerSelecting(selectedChildNodes.compactMap({ $0.url }))
    }
    
    @IBAction func openInTab(_ sender: Any?) {
        selectedChildNodes.forEach { [unowned self] node in
            self.browserController.openInternalNode(node)
        }
    }
    
    @IBAction func openWithExternalEditor(_ sender: Any?) {
        selectedChildNodes.forEach { [unowned self] node in
            self.browserController.openExternalNode(node)
        }
    }
    
    private func reloadClickedColumn() {
        var operatingColumn = browser.clickedColumn
        if actionIsPreview {
            operatingColumn -= 1
        }
        if let parentNode = browser.parentForItems(inColumn: operatingColumn) as? FileSystemNode {
            parentNode.invalidateChildren()
        }
        browser.reloadColumn(operatingColumn)
    }
    
    @IBAction func moveToTrash(_ sender: Any?) {
        selectedChildNodes.forEach { node in
            try? FileManager.default.trashItem(at: node.url, resultingItemURL: nil)
        }
        reloadClickedColumn()
    }
    
    @IBAction func duplicate(_ sender: Any?) {
        NSWorkspace.shared.duplicate(selectedChildNodes.compactMap({ $0.url })) { [weak self] _, err in
            // TODO: select newly created items
            if let err = err {
                self?.presentError(err)
            }
            self?.reloadClickedColumn()
        }
    }

    func promiseCheckFilename(_ name: String) -> Promise<String> {
        return Promise<String> { seal in
            if name.isEmpty || name.hasPrefix(".") || name.contains("/") {
                seal.reject(GenericError.invalidFilename(name: name))
                return
            }
            seal.fulfill(name)
        }
    }

    func promiseCreateNewFolder(inParentNode parent: FileSystemNode, withName folderName: String) -> Promise<URL> {
        return Promise<URL> { seal in
            do {
                let targetURL = parent.url.appendingPathComponent(folderName, isDirectory: true)
                try FileManager.default.createDirectory(
                    at: targetURL,
                    withIntermediateDirectories: false,
                    attributes: nil
                )
                seal.fulfill(targetURL)
            } catch let err {
                seal.reject(err)
            }
        }
    }

    func promiseMoveNodes(_ nodes: [FileSystemNode], to destinationBaseURL: URL) -> Promise<URL> {
        return Promise<URL> { seal in
            do {
                try nodes.forEach { node in
                    try FileManager.default.moveItem(at: node.url, to: destinationBaseURL.appendingPathComponent(node.url.lastPathComponent))
                }
                seal.fulfill(destinationBaseURL)
            } catch let err {
                seal.reject(err)
            }
        }
    }

    func promiseMoveNode(_ node: FileSystemNode, to destinationURL: URL) -> Promise<URL> {
        return Promise<URL> { seal in
            do {
                try FileManager.default.moveItem(at: node.url, to: destinationURL)
                seal.fulfill(destinationURL)
            } catch let err {
                seal.reject(err)
            }
        }
    }

    func promiseRenameNode(_ node: FileSystemNode, withNewName newName: String) -> Promise<URL> {
        let newURL = node.url
            .deletingLastPathComponent()
            .appendingPathComponent(newName)
        return promiseMoveNode(node, to: newURL)
    }

    func promiseReloadColumn(at url: URL) -> Promise<Void> {
        let parentURL = url.deletingLastPathComponent()
        var reloadIndex: Int? = nil
        for columnIndex in (0...browser.lastColumn).reversed() {
            guard let parentNode = browser.parentForItems(inColumn: columnIndex) as? FileSystemNode else { continue }
            if parentNode.url == parentURL {
                parentNode.invalidateChildren()
                reloadIndex = columnIndex
            }
        }
        return Promise<Void> { [weak self] seal in
            if let reloadIndex = reloadIndex {
                self?.browser.reloadColumn(reloadIndex)
                seal.fulfill(())
            } else {
                seal.reject(GenericError.notDirectory(url: url))
            }
        }
    }
    
    @IBAction func newFolder(_ sender: Any?) {
        let childNodes = browser.clickedRow >= 0 ? selectedChildNodes : []
        if let parentNode = selectedParentNode {
            NSAlert.textField(
                window: browser.window,
                text: .init(
                    message: NSLocalizedString("Create New Folder", comment: "newFolder(_:)")
                ),
                textField: .init(
                    text: NSLocalizedString("Untitled Folder", comment: "newFolder(_:)"),
                    placeholder: NSLocalizedString("Folder Name", comment: "newFolder(_:)")
                ),
                button: .init(
                    title: NSLocalizedString("OK", comment: "newFolder(_:)")
                )
            ).then { [unowned self] folderName in
                return self.promiseCheckFilename(folderName)
            }.then { [unowned self] folderName in
                return self.promiseCreateNewFolder(inParentNode: parentNode, withName: folderName)
            }.then { [unowned self] folderURL in
                return self.promiseMoveNodes(childNodes, to: folderURL)
            }.then { [unowned self] folderURL in
                return self.promiseReloadColumn(at: folderURL)
            }.catch { [weak self] error in
                if let window = self?.browser.window {
                    NSAlert(error: error).beginSheetModal(
                        for: window, completionHandler: nil
                    )
                }
            }
        }
    }

    @IBAction func rename(_ sender: Any?) {
        if let childNode = browser.clickedRow >= 0 ? selectedChildNodes.first : nil {
            let oldName = childNode.url.lastPathComponent
            NSAlert.textField(
                window: browser.window,
                text: .init(
                    message: NSLocalizedString("Rename", comment: "rename(_:)")
                ),
                textField: .init(
                    text: oldName,
                    placeholder: NSLocalizedString("New Name", comment: "rename(_:)")
                ),
                button: .init(
                    title: NSLocalizedString("OK", comment: "rename(_:)")
                )
            ).then { [unowned self] fileName in
                return self.promiseCheckFilename(fileName)
            }.then { [unowned self] fileName in
                return self.promiseRenameNode(childNode, withNewName: fileName)
            }.then { [unowned self] newItemURL in
                return self.promiseReloadColumn(at: newItemURL)
            }.catch { [weak self] error in
                if let window = self?.browser.window {
                    NSAlert(error: error).beginSheetModal(
                        for: window, completionHandler: nil
                    )
                }
            }
        }
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
