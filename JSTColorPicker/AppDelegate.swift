//
//  AppDelegate.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/12/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa
import MASPreferences

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var tabService: TabService?
    let matchService = PixelMatchService()
    let deviceService = JSTDeviceService()
    let gridController = GridWindowController.newGrid()
    lazy var preferencesController: NSWindowController = {
        let generalController = GeneralController()
        let folderController = FolderController()
        let advancedController = AdvancedController()
        let controller = PreferencesController(viewControllers: [generalController, folderController, advancedController], title: NSLocalizedString("Preferences", comment: "PreferencesController"))
        return controller
    }()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        let initialValues: [UserDefaults.Key: Any?] = [
            
            .enableNetworkDiscovery: false,
            
            .enableForceTouch: true,
            .drawSceneBackground: true,
            .drawGridsInScene: true,
            .drawRulersInScene: true,
            .drawBackgroundInGridView: true,
            .drawAnnotatorsInGridView: false,
            .hideGridsWhenResize: false,
            .hideAnnotatorsWhenResize: true,
            .usesPredominantAxisScrolling: false,
            
            .confirmBeforeDelete: true,
            .maximumItemCountEnabled: true,
            .maximumItemCount: 99,
            
            .screenshotSavingPath: FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first?.appendingPathComponent("JSTColorPicker").path,
            
            .pixelMatchThreshold: 0.1,
            .pixelMatchIncludeAA: false,
            .pixelMatchAlpha: 0.5,
            .pixelMatchAAColor: NSColor.systemYellow,
            .pixelMatchDiffColor: NSColor.systemRed,
            .pixelMatchDiffMask: true,
            
        ]
        
        UserDefaults.standard.register(defaults: initialValues)
        
        deviceService.delegate = self
        reloadiDevices()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        
    }
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        let windowController = reinitializeTabService()
        windowController.showWindow(self)
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func reinitializeTabService() -> WindowController {
        let windowController = WindowController.newEmptyWindow()
        tabService = TabService(initialWindowController: windowController)
        return windowController
    }
    
    @IBAction func showGithubPage(_ sender: NSMenuItem) {
        if let url = Bundle.main.url(forResource: "JSTColorPicker", withExtension: "html") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @IBOutlet weak var enableNetworkDiscoveryMenuItem: NSMenuItem!
    @IBOutlet weak var devicesMenu: NSMenu!
    
    fileprivate static let deviceIdentifierPrefix = "device-"
    fileprivate var selectedDeviceUDID: String? {
        get {
            return UserDefaults.standard[.lastSelectedDeviceUDID]
        }
        set {
            UserDefaults.standard[.lastSelectedDeviceUDID] = newValue
        }
    }
    fileprivate static var screenshotDateFormatter: DateFormatter = {
        let formatter = DateFormatter.init()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter
    }()
    
    @IBAction func enableNetworkDiscoveryItemTapped(_ sender: NSMenuItem) {
        sender.state = sender.state == .on ? .off : .on
        UserDefaults.standard[.enableNetworkDiscovery] = sender.state == .on
        reloadiDevices()
    }
    
    @IBAction func screenshotItemTapped(_ sender: Any?) {
        guard let windowController = tabService?.firstRespondingWindow?.windowController as? WindowController else { return }
        guard let picturesDirectoryPath: String = UserDefaults.standard[.screenshotSavingPath] else { return }
        let picturesDirectoryURL = URL(fileURLWithPath: NSString(string: picturesDirectoryPath).standardizingPath)
        if let selectedDeviceUDID = selectedDeviceUDID {
            if let device = JSTDevice(udid: selectedDeviceUDID) {
                let loadingAlert = NSAlert()
                loadingAlert.messageText = NSLocalizedString("Waiting for device", comment: "screenshotItemTapped(_:)")
                loadingAlert.informativeText = String(format: NSLocalizedString("Downloading screenshot from device \"%@\"...", comment: "screenshotItemTapped(_:)"), device.name)
                loadingAlert.addButton(withTitle: NSLocalizedString("Cancel", comment: "screenshotItemTapped(_:)"))
                loadingAlert.alertStyle = .informational
                loadingAlert.buttons.first?.isHidden = true
                windowController.showSheet(loadingAlert, completionHandler: nil)
                DispatchQueue.global(qos: .default).async {
                    device.screenshot { (data, error) in
                        DispatchQueue.main.async {
                            if let error = error {
                                let alert = NSAlert(error: error)
                                windowController.showSheet(alert, completionHandler: nil)
                            } else if let data = data {
                                do {
                                    var isDirectory: ObjCBool = false
                                    if !FileManager.default.fileExists(atPath: picturesDirectoryURL.path, isDirectory: &isDirectory) {
                                        try FileManager.default.createDirectory(at: picturesDirectoryURL, withIntermediateDirectories: true, attributes: nil)
                                    }
                                    var picturesURL = picturesDirectoryURL
                                    picturesURL.appendPathComponent("screenshot_\(AppDelegate.screenshotDateFormatter.string(from: Date.init()))")
                                    picturesURL.appendPathExtension("png")
                                    try data.write(to: picturesURL)
                                    NSDocumentController.shared.openDocument(withContentsOf: picturesURL, display: true) { (document, documentWasAlreadyOpen, error) in
                                        if let error = error {
                                            let alert = NSAlert(error: error)
                                            windowController.showSheet(alert, completionHandler: nil)
                                        } else {
                                            windowController.showSheet(nil, completionHandler: nil)
                                        }
                                    }
                                } catch let error {
                                    let alert = NSAlert(error: error)
                                    windowController.showSheet(alert, completionHandler: nil)
                                }
                            } else {
                                windowController.showSheet(nil, completionHandler: nil)
                            }
                        }
                    }
                }
            } else {
                let alert = NSAlert()
                alert.messageText = NSLocalizedString("Unable to connect", comment: "screenshotItemTapped(_:)")
                alert.informativeText = NSLocalizedString("Try again later.", comment: "screenshotItemTapped(_:)")
                alert.addButton(withTitle: NSLocalizedString("OK", comment: "screenshotItemTapped(_:)"))
                alert.alertStyle = .warning
                windowController.showSheet(alert, completionHandler: nil)
            }
        } else {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("No device available", comment: "screenshotItemTapped(_:)")
            alert.informativeText = NSLocalizedString("Connect to your iOS device via USB or network.", comment: "screenshotItemTapped(_:)")
            alert.addButton(withTitle: NSLocalizedString("OK", comment: "screenshotItemTapped(_:)"))
            alert.alertStyle = .warning
            windowController.showSheet(alert, completionHandler: nil)
        }
    }
    
    @IBOutlet weak var showGridItem: NSMenuItem!
    var isGridVisible: Bool {
        guard let visible = gridController.window?.isVisible else { return false }
        return visible
    }
    @IBAction func gridSwitchItemTapped(_ sender: Any?) {
        if isGridVisible {
            gridController.close()
        } else {
            gridController.showWindow(sender)
        }
    }
    
    @IBAction func preferencesItemTapped(_ sender: Any?) {
        preferencesController.showWindow(sender)
    }
    
    @IBOutlet weak var showColorPanelItem: NSMenuItem!
    
    @IBAction func colorPanelSwitchItemTapped(_ sender: Any) {
        if !NSColorPanel.shared.isVisible {
            NSColorPanel.shared.orderFront(sender)
        } else {
            NSColorPanel.shared.close()
        }
    }
    
}

extension AppDelegate: NSMenuDelegate {
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        updateMenuItems()
    }
    
}

extension AppDelegate: JSTDeviceDelegate {
    
    func reloadiDevices() {
        DispatchQueue.global(qos: .default).async { [weak self] in
            self?.didReceiveiDeviceEvent()
        }
    }
    
    fileprivate func didReceiveiDeviceEvent() {
        didReceiveiDeviceEvent(self.deviceService)
    }
    
    func didReceiveiDeviceEvent(_ service: JSTDeviceService) {
        let enableNetworkDiscovery: Bool = UserDefaults.standard[.enableNetworkDiscovery]
        
        let devices = service.devices(includingNetworkDevices: enableNetworkDiscovery)
            .sorted(by: { $0.name.compare($1.name) == .orderedAscending })
        debugPrint(devices)
        
        DispatchQueue.main.async { [weak self] in
            var items: [NSMenuItem] = []
            for device in devices {
                let item = NSMenuItem(title: device.menuTitle, action: #selector(self?.deviceItemTapped(_:)), keyEquivalent: "")
                item.identifier = NSUserInterfaceItemIdentifier(rawValue: "\(AppDelegate.deviceIdentifierPrefix)\(device.udid)")
                items.append(item)
            }
            
            if items.count > 0 {
                self?.devicesMenu.items = items
            } else {
                self?.resetDevicesMenu()
            }
            
            self?.updateMenuItems()
        }
    }
    
    @objc func deviceItemTapped(_ sender: NSMenuItem) {
        selectDeviceItem(sender)
    }
    
    fileprivate func resetDevicesMenu() {
        let emptyItem = NSMenuItem(title: NSLocalizedString("No device found.", comment: "resetDevicesMenu"), action: nil, keyEquivalent: "")
        emptyItem.identifier = NSUserInterfaceItemIdentifier(rawValue: "")
        emptyItem.state = .off
        devicesMenu.items = [
            emptyItem
        ]
    }
    
    fileprivate func updateMenuItems() {
        enableNetworkDiscoveryMenuItem.state = UserDefaults.standard[.enableNetworkDiscovery] ? .on : .off
        var selectedDeviceExists = false
        let selectedDeviceIdentifier = "\(AppDelegate.deviceIdentifierPrefix)\(selectedDeviceUDID ?? "")"
        for item in devicesMenu.items {
            if let identifier = item.identifier?.rawValue {
                if identifier == selectedDeviceIdentifier {
                    item.state = .on
                    selectedDeviceExists = true
                } else {
                    item.state = .off
                }
            }
        }
        if !selectedDeviceExists {
            if let firstItem = devicesMenu.items.first {
                selectDeviceItem(firstItem)
            } else {
                selectedDeviceUDID = nil
            }
        }
    }
    
    fileprivate func selectDeviceItem(_ sender: NSMenuItem) {
        guard let identifier = sender.identifier?.rawValue else { return }
        guard identifier.lengthOfBytes(using: .utf8) > 0 else { return }
        let beginIdx = identifier.index(identifier.startIndex, offsetBy: AppDelegate.deviceIdentifierPrefix.lengthOfBytes(using: .utf8))
        let udid = String(identifier[beginIdx...])
        selectedDeviceUDID = udid
    }
    
}

