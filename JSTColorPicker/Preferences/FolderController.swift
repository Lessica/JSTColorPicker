//
//  FolderController.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/28/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa
import MASPreferences

class FolderController: NSViewController {
    
    @IBOutlet weak var screenshotSavedAtLocationButton       : NSButton!
    @IBOutlet weak var tagDatabaseLocationButton             : NSButton!
    @IBOutlet weak var templatesRootLocationButton           : NSButton!
    @IBOutlet weak var screenshotHelperLocationButton        : NSButton!
    
    @IBOutlet weak var screenshotSavedAtLocationPopUpButton  : NSPopUpButton!
    @IBOutlet weak var tagDatabaseLocationLabel              : NSTextField!
    @IBOutlet weak var templatesRootLocationLabel            : NSTextField!
    @IBOutlet weak var screenshotHelperLocationLabel         : NSTextField!
    
    init() {
        super.init(nibName: "Folder", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tagDatabaseLocationLabel.stringValue = TagListController.persistentStoreDirectoryURL.path
        templatesRootLocationLabel.stringValue = TemplateManager.templateRootURL.path
        screenshotHelperLocationLabel.stringValue = GetJSTColorPickerHelperApplicationPath()
    }
    
    @IBAction func locationButtonTapped(_ sender: NSButton) {
        var isDirectory: Bool = false
        var locationURL: URL?
        if sender == screenshotSavedAtLocationButton {
            if let locationPath: String = UserDefaults.standard[.screenshotSavingPath] {
                locationURL = URL(fileURLWithPath: NSString(string: locationPath).standardizingPath)
                isDirectory = true
            }
        }
        else if sender == tagDatabaseLocationButton {
            locationURL = TagListController.persistentStoreDirectoryURL
            isDirectory = true
        }
        else if sender == templatesRootLocationButton {
            locationURL = TemplateManager.templateRootURL
            isDirectory = true
        }
        else if sender == screenshotHelperLocationButton {
            locationURL = URL(fileURLWithPath: GetJSTColorPickerHelperApplicationPath())
            isDirectory = false
        }
        if let url = locationURL {
            guard FileManager.default.fileExists(atPath: url.path) else {
                // TODO: presentError
                return
            }
            if isDirectory {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
            } else {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }
    
    @IBAction func actionRequiresRestart(_ sender: NSButton) { }
    
}

extension FolderController: MASPreferencesViewController {
    
    var hasResizableWidth: Bool {
        return false
    }
    
    var hasResizableHeight: Bool {
        return false
    }
    
    var viewIdentifier: String {
        return "FolderPreferences"
    }
    
    var toolbarItemLabel: String? {
        return NSLocalizedString("Folder", comment: "toolbarItemLabel")
    }
    
    var toolbarItemImage: NSImage? {
        return NSImage(systemSymbolName: "folder", accessibilityDescription: "Folder")
    }
    
}
