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
        reloadUI()
        
        #if APP_STORE
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationHelperDidBecomeAvailable(_:)),
            name: AppDelegate.applicationHelperDidBecomeAvailableNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationHelperDidResignAvailable(_:)),
            name: AppDelegate.applicationHelperDidResignAvailableNotification,
            object: nil
        )
        #endif
    }
    
    private func reloadUI() {
        tagDatabaseLocationLabel.stringValue = TagListController.persistentStoreDirectoryURL.path
        templatesRootLocationLabel.stringValue = TemplateManager.templateRootURL.path
        #if APP_STORE
        if AppDelegate.shared.applicationHasScreenshotHelper() {
            screenshotHelperLocationLabel.stringValue = GetJSTColorPickerHelperApplicationPath()
            screenshotHelperLocationButton.isHidden = false
        } else {
            screenshotHelperLocationLabel.stringValue = NSLocalizedString("(Not Installed)", comment: "FolderController")
            screenshotHelperLocationButton.isHidden = true
        }
        #else
        screenshotHelperLocationLabel.stringValue = NSLocalizedString("(Not Installed)", comment: "FolderController")
        screenshotHelperLocationButton.isHidden = true
        #endif
    }
    
    @IBAction func locationButtonTapped(_ sender: NSButton) {
        var isDirectory: Bool = false
        var locationURL: URL?
        if sender == screenshotSavedAtLocationButton {
            if let locationPath: String = UserDefaults.standard[.screenshotSavingPath] {
                locationURL = URL(fileURLWithPath: NSString(string: locationPath).standardizingPath)
                guard locationURL!.isDirectory else {
                    presentError(GenericError.notDirectory(url: locationURL!))
                    return
                }
                isDirectory = true
            }
        }
        else if sender == tagDatabaseLocationButton {
            locationURL = TagListController.persistentStoreDirectoryURL
            guard locationURL!.isDirectory else {
                presentError(GenericError.notDirectory(url: locationURL!))
                return
            }
            isDirectory = true
        }
        else if sender == templatesRootLocationButton {
            locationURL = TemplateManager.templateRootURL
            guard locationURL!.isDirectory else {
                presentError(GenericError.notDirectory(url: locationURL!))
                return
            }
            isDirectory = true
        }
        else if sender == screenshotHelperLocationButton {
            locationURL = URL(fileURLWithPath: GetJSTColorPickerHelperApplicationPath())
            guard locationURL!.isPackage else {
                presentError(GenericError.notPackage(url: locationURL!))
                return
            }
            isDirectory = false
        }
        if let url = locationURL {
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

extension FolderController {
    @objc private func applicationHelperDidBecomeAvailable(_ noti: Notification) {
        reloadUI()
    }
    
    @objc private func applicationHelperDidResignAvailable(_ noti: Notification) {
        reloadUI()
    }
}
