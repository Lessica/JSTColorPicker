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
    lazy var deviceService: JSTDeviceService = {
        return JSTDeviceService()
    }()
    lazy var colorGridController: ColorGridWindowController = {
        let controller = ColorGridWindowController.newGrid()
        controller.window?.level = .floating
        return controller
    }()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        deviceService.delegate = self
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
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
    
    @IBOutlet weak var devicesMenu: NSMenu!
    fileprivate let deviceIdentifierPrefix = "device-"
    fileprivate var selectedDeviceUDID: String?
    fileprivate static var screenshotDateFormatter: DateFormatter = {
        let formatter = DateFormatter.init()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter
    }()
    fileprivate static func fileExtensionForScreenshotType(_ type: JSTScreenshotType) -> String {
        var imageType: String!
        if type == JSTScreenshotTypePNG {
            imageType = "png"
        }
        else if type == JSTScreenshotTypeTIFF {
            imageType = "tiff"
        }
        else {
            imageType = "dat"
        }
        return imageType
    }
    
    @IBAction func screenshotItemTapped(_ sender: Any?) {
        guard let windowController = tabService?.firstRespondingWindow?.windowController as? WindowController else { return }
        guard let picturesDirectory = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first else { return }
        if let selectedDeviceUDID = selectedDeviceUDID {
            if let device = JSTDevice(udid: selectedDeviceUDID) {
                let loadingAlert = NSAlert()
                loadingAlert.messageText = "Waiting for device"
                loadingAlert.informativeText = "Downloading screenshot from device..."
                loadingAlert.addButton(withTitle: "Cancel")
                loadingAlert.alertStyle = .informational
                loadingAlert.buttons.first?.isHidden = true
                windowController.showSheet(loadingAlert, completionHandler: nil)
                device.screenshot { (type, data, error) in
                    if let error = error {
                        let alert = NSAlert(error: error)
                        windowController.showSheet(alert, completionHandler: nil)
                    } else if let data = data {
                        var picturesURL = picturesDirectory
                        picturesURL.appendPathComponent("screenshot_\(AppDelegate.screenshotDateFormatter.string(from: Date.init()))")
                        picturesURL.appendPathExtension(AppDelegate.fileExtensionForScreenshotType(type))
                        do {
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
    
    @IBOutlet weak var showColorGridItem: NSMenuItem!
    var isColorGridVisible: Bool {
        guard let visible = colorGridController.window?.isVisible else { return false }
        return visible
    }
    @IBAction func colorGridSwitchItemTapped(_ sender: Any?) {
        if isColorGridVisible {
            colorGridController.close()
        } else {
            colorGridController.showWindow(sender)
        }
    }
    
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        updateSelectedDeviceItem()
    }
}

extension AppDelegate: JSTDeviceDelegate {
    
    func deviceService(_ service: JSTDeviceService, handleiDeviceEvent event: UnsafePointer<idevice_event_t>) {
        debugPrint(service.devices)
        var items: [NSMenuItem] = []
        for device in service.devices {
            let item = NSMenuItem(title: device.menuTitle, action: #selector(deviceItemTapped(_:)), keyEquivalent: "")
            item.identifier = NSUserInterfaceItemIdentifier(rawValue: "\(deviceIdentifierPrefix)\(device.udid)")
            items.append(item)
        }
        if items.count > 0 {
            devicesMenu.items = items
        } else {
            let emptyItem = NSMenuItem(title: "No device found.", action: nil, keyEquivalent: "")
            devicesMenu.items = [
                emptyItem
            ]
        }
        updateSelectedDeviceItem()
    }
    
    @objc func deviceItemTapped(_ sender: NSMenuItem) {
        selectDeviceItem(sender)
    }
    
    fileprivate func updateSelectedDeviceItem() {
        var exists = false
        let selectedDeviceIdentifier = "\(deviceIdentifierPrefix)\(selectedDeviceUDID ?? "")"
        for item in devicesMenu.items {
            if let identifier = item.identifier?.rawValue {
                if identifier == selectedDeviceIdentifier {
                    item.state = .on
                    exists = true
                } else {
                    item.state = .off
                }
            }
        }
        if !exists {
            if let firstItem = devicesMenu.items.first {
                selectDeviceItem(firstItem)
            } else {
                selectedDeviceUDID = nil
            }
        }
    }
    
    fileprivate func selectDeviceItem(_ sender: NSMenuItem) {
        guard let identifier = sender.identifier?.rawValue else {
            return
        }
        let beginIdx = identifier.index(identifier.startIndex, offsetBy: deviceIdentifierPrefix.lengthOfBytes(using: .utf8))
        let udid = identifier[beginIdx...]
        selectedDeviceUDID = String(udid)
    }
    
}

