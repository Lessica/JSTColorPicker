//
//  AppDelegate.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/12/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var tabService: TabService?
    let deviceService = JSTDeviceService()
    let gridController = GridWindowController.newGrid()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        UserDefaults.standard.register(defaults: [
            .enableNetworkDiscovery: true,
            .screenshotSavingPath: FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first?.appendingPathComponent("JSTColorPicker")
        ])
        
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
        if let url = URL.init(string: "https://github.com/Lessica/JSTColorPicker") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @IBOutlet weak var enableNetworkDiscoveryMenuItem: NSMenuItem!
    @IBOutlet weak var devicesMenu: NSMenu!
    
    fileprivate let deviceIdentifierPrefix = "device-"
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
        guard let picturesDirectory: URL = UserDefaults.standard[.screenshotSavingPath] else { return }
        if let selectedDeviceUDID = selectedDeviceUDID {
            if let device = JSTDevice(udid: selectedDeviceUDID) {
                let loadingAlert = NSAlert()
                loadingAlert.messageText = "Waiting for device"  // TODO: to be localized
                loadingAlert.informativeText = "Downloading screenshot from device \"\(device.name)\"..."
                loadingAlert.addButton(withTitle: "Cancel")
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
                                    if !FileManager.default.fileExists(atPath: picturesDirectory.path, isDirectory: &isDirectory) {
                                        try FileManager.default.createDirectory(at: picturesDirectory, withIntermediateDirectories: true, attributes: nil)
                                    }
                                    var picturesURL = picturesDirectory
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
                alert.messageText = "Unable to connect"
                alert.informativeText = "Try again later."
                alert.addButton(withTitle: "OK")
                alert.alertStyle = .warning
                windowController.showSheet(alert, completionHandler: nil)
            }
        } else {
            let alert = NSAlert()
            alert.messageText = "No device available"
            alert.informativeText = "Connect to your iOS device via USB or network."
            alert.addButton(withTitle: "OK")
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
        // TODO: preferences panel
        let alert = NSAlert()
        alert.messageText = "Not Implemented"
        alert.informativeText = "Preferences panel is not designed yet."
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        alert.runModal()
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
        didReceiveiDeviceEvent(deviceService)
    }
    
    func didReceiveiDeviceEvent(_ service: JSTDeviceService) {
        let devices = service.devices(includingNetworkDevices: UserDefaults.standard[.enableNetworkDiscovery])
            .sorted(by: { $0.name.compare($1.name) == .orderedAscending })
        debugPrint(devices)
        
        var items: [NSMenuItem] = []
        for device in devices {
            let item = NSMenuItem(title: device.menuTitle, action: #selector(deviceItemTapped(_:)), keyEquivalent: "")
            item.identifier = NSUserInterfaceItemIdentifier(rawValue: "\(deviceIdentifierPrefix)\(device.udid)")
            items.append(item)
        }
        
        if items.count > 0 {
            devicesMenu.items = items
        } else {
            resetDevicesMenu()
        }
        
        updateMenuItems()
    }
    
    @objc func deviceItemTapped(_ sender: NSMenuItem) {
        selectDeviceItem(sender)
    }
    
    fileprivate func resetDevicesMenu() {
        let emptyItem = NSMenuItem(title: "No device found.", action: nil, keyEquivalent: "")
        emptyItem.identifier = NSUserInterfaceItemIdentifier(rawValue: "")
        emptyItem.state = .off
        devicesMenu.items = [
            emptyItem
        ]
    }
    
    fileprivate func updateMenuItems() {
        enableNetworkDiscoveryMenuItem.state = UserDefaults.standard[.enableNetworkDiscovery] ? .on : .off
        var selectedDeviceExists = false
        let selectedDeviceIdentifier = "\(deviceIdentifierPrefix)\(selectedDeviceUDID ?? "")"
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
        let beginIdx = identifier.index(identifier.startIndex, offsetBy: deviceIdentifierPrefix.lengthOfBytes(using: .utf8))
        let udid = String(identifier[beginIdx...])
        selectedDeviceUDID = udid
    }
    
}

