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
    
    public var tabService: TabService?
    public let deviceService = JSTDeviceService()
    public let gridController = GridWindowController.newGrid()
    private lazy var preferencesController: NSWindowController = {
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
            .pixelMatchIncludeAA: true,
            .pixelMatchAlpha: 0.5,
            .pixelMatchAAColor: NSColor.systemYellow,
            .pixelMatchDiffColor: NSColor.systemRed,
            .pixelMatchDiffMask: false,
            .pixelMatchBackgroundMode: false,
            
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
    
    public func reinitializeTabService() -> WindowController {
        let windowController = WindowController.newEmptyWindow()
        tabService = TabService(initialWindowController: windowController)
        return windowController
    }
    
    
    // MARK: - Preferences Actions
    
    @IBAction func preferencesItemTapped(_ sender: Any?) {
        preferencesController.showWindow(sender)
    }
    
    
    // MARK: - Compare Actions
    
    @IBOutlet weak var compareMenuItem: NSMenuItem!
    
    fileprivate var preparedPixelMatchTuple: (WindowController, [PixelImage])? {
        guard let managedWindows = tabService?.managedWindows else { return nil }
        let preparedManagedWindows = managedWindows.filter({ ($0.windowController.screenshot?.isLoaded ?? false ) })
        guard preparedManagedWindows.count >= 2,
            let firstWindowController = managedWindows.first?.windowController,
            let firstPreparedWindowController = preparedManagedWindows.first?.windowController,
            firstWindowController === firstPreparedWindowController
            else { return nil }
        return (firstWindowController, preparedManagedWindows.compactMap({ $0.windowController.screenshot?.image }))
    }
    
    fileprivate var firstManagedWindowController: WindowController? {
        return tabService?.firstManagedWindow?.windowController
    }
    
    @IBAction func compareMenuItemTapped(_ sender: Any?) {
        if firstManagedWindowController?.shouldEndPixelMatchComparison ?? false {
            firstManagedWindowController?.endPixelMatchComparison()
        }
        else if let tuple = preparedPixelMatchTuple {
            if let frontPixelImage = tuple.0.screenshot?.image {
                if let anotherPixelImage = tuple.1.first(where: { $0 !== frontPixelImage }) {
                    tuple.0.beginPixelMatchComparison(to: anotherPixelImage)
                }
            }
        }
    }
    
    
    // MARK: - Color Grid Actions
    
    @IBOutlet weak var gridSwitchMenuItem: NSMenuItem!
    
    fileprivate var isGridVisible: Bool {
        guard let visible = gridController.window?.isVisible else { return false }
        return visible
    }
    
    @IBAction func gridSwitchMenuItemTapped(_ sender: Any?) {
        if isGridVisible {
            gridController.close()
        } else {
            gridController.showWindow(sender)
        }
    }
    
    
    // MARK: - Color Panel Actions
    
    @IBOutlet weak var colorPanelSwitchMenuItem: NSMenuItem!
    
    @IBAction func colorPanelSwitchMenuItemTapped(_ sender: Any) {
        if !NSColorPanel.shared.isVisible {
            NSColorPanel.shared.orderFront(sender)
        } else {
            NSColorPanel.shared.close()
        }
    }
    
    
    // MARK: - Device Actions
    
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
    
    @IBAction func enableNetworkDiscoveryMenuItemTapped(_ sender: NSMenuItem) {
        sender.state = sender.state == .on ? .off : .on
        UserDefaults.standard[.enableNetworkDiscovery] = sender.state == .on
        reloadiDevices()
    }
    
    @IBAction func screenshotMenuItemTapped(_ sender: Any?) {
        guard let windowController = tabService?.firstRespondingWindow?.windowController as? WindowController else { return }
        guard let picturesDirectoryPath: String = UserDefaults.standard[.screenshotSavingPath] else { return }
        let picturesDirectoryURL = URL(fileURLWithPath: NSString(string: picturesDirectoryPath).standardizingPath)
        if let selectedDeviceUDID = selectedDeviceUDID {
            if let device = JSTDevice(udid: selectedDeviceUDID) {
                let loadingAlert = NSAlert()
                loadingAlert.messageText = NSLocalizedString("Waiting for device", comment: "screenshotItemTapped(_:)")
                loadingAlert.informativeText = String(format: NSLocalizedString("Downloading screenshot from device \"%@\"...", comment: "screenshotItemTapped(_:)"), device.name)
                let loadingIndicator = NSProgressIndicator(frame: CGRect(x: 0, y: 0, width: 24.0, height: 24.0))
                loadingIndicator.style = .spinning
                loadingIndicator.startAnimation(nil)
                loadingAlert.accessoryView = loadingIndicator
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
    
    
    // MARK: - Help Actions
    
    @IBAction func showHelpPageMenuItemTapped(_ sender: NSMenuItem) {
        if let url = Bundle.main.url(forResource: "JSTColorPicker", withExtension: "html") {
            NSWorkspace.shared.open(url)
        }
    }
    
}

extension AppDelegate: NSUserInterfaceValidations {
    
    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(compareMenuItemTapped(_:)) {
            if firstManagedWindowController?.shouldEndPixelMatchComparison ?? false {
                return true
            }
            else if preparedPixelMatchTuple != nil {
                return true
            }
            else {
                return false
            }
        }
        return true
    }
    
}

extension AppDelegate: NSMenuDelegate {
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        updateFileMenuItems()
        updateDevicesMenuItems()
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
            
            self?.updateDevicesMenuItems()
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
    
    fileprivate func updateFileMenuItems() {
        if firstManagedWindowController?.shouldEndPixelMatchComparison ?? false {
            compareMenuItem.title = NSLocalizedString("Exit Comparison Mode", comment: "updateMenuItems")
            compareMenuItem.isEnabled = true
        }
        else if let tuple = preparedPixelMatchTuple {
            let name1 = tuple.1[0].imageSource.url.lastPathComponent
            let name2 = tuple.1[1].imageSource.url.lastPathComponent
            compareMenuItem.title = String(format: NSLocalizedString("Compare \"%@\" and \"%@\"", comment: "updateMenuItems"), name1, name2)
            compareMenuItem.isEnabled = true
        }
        else {
            compareMenuItem.title = NSLocalizedString("Compare Opened Documents", comment: "updateMenuItems")
            compareMenuItem.isEnabled = false
        }
    }
    
    fileprivate func updateDevicesMenuItems() {
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

