//
//  AppDelegate+Device.swift
//  JSTColorPicker
//
//  Created by Rachel on 6/8/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa
import PromiseKit


// MARK: - XPC Connection

extension AppDelegate {
    
    private var selectedDeviceUDID: String?
    {
        get { UserDefaults.standard[.lastSelectedDeviceUDID]            }
        set { UserDefaults.standard[.lastSelectedDeviceUDID] = newValue }
    }
    
    private static let deviceIdentifierPrefix: String = "device-"
    private static var screenshotDateFormatter: DateFormatter =
        {
            let formatter = DateFormatter.init()
            formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
            return formatter
        }()
    
    #if APP_STORE
    static let applicationHelperDidBecomeAvailableNotification = Notification.Name("AppDelegate.applicationHelperDidBecomeAvailableNotification")
    static let applicationHelperDidResignAvailableNotification = Notification.Name("AppDelegate.applicationHelperDidResignAvailableNotification")
    #endif
    
    #if APP_STORE
    private var _isScreenshotHelperAvailable: Bool = false
    {
        didSet {
            if _isScreenshotHelperAvailable {
                NotificationCenter.default.post(
                    name: AppDelegate.applicationHelperDidBecomeAvailableNotification,
                    object: self
                )
            } else {
                NotificationCenter.default.post(
                    name: AppDelegate.applicationHelperDidResignAvailableNotification,
                    object: self
                )
            }
        }
    }
    #endif
    
    
    // MARK: - XPC Functions
    
    internal func applicationXPCEstablish() {
        if let prevConnection = self.helperConnection {
            prevConnection.invalidate()
            self.helperConnection = nil
        }
        
        #if APP_STORE
        let connectionToService = NSXPCConnection(machServiceName: kJSTColorPickerHelperBundleIdentifier)
        #else
        let connectionToService = NSXPCConnection(serviceName: kJSTScreenshotHelperBundleIdentifier)
        #endif
        
        connectionToService.interruptionHandler = { debugPrint("xpc conection interrupted") }
        connectionToService.invalidationHandler = { debugPrint("xpc conection invalidated") }  // <- error occurred
        connectionToService.remoteObjectInterface = NSXPCInterface(with: JSTScreenshotHelperProtocol.self)
        connectionToService.resume()
        
        self.helperConnection = connectionToService
    }
    
    @objc private func applicationHelperDidBecomeAvailable(_ noti: Notification) {
        applicationXPCEstablish()
    }
    
    @objc private func applicationHelperDidResignAvailable(_ noti: Notification) {
        applicationXPCResetUI()
        
        self.helperConnection?.invalidate()
        self.helperConnection = nil
    }
    
    #if APP_STORE
    @discardableResult
    func applicationHasScreenshotHelper() -> Bool {
        let launchAgentPath = GetJSTColorPickerHelperLaunchAgentPath()
        let isAvailable = FileManager.default.fileExists(atPath: launchAgentPath)
        if isAvailable != _isScreenshotHelperAvailable {
            _isScreenshotHelperAvailable = isAvailable
        }
        return isAvailable
    }
    #else
    @discardableResult
    func applicationHasScreenshotHelper() -> Bool {
        return true
    }
    #endif
    
    internal func applicationXPCSetup() {
        let enabled: Bool = UserDefaults.standard[.enableNetworkDiscovery]
        if let proxy = self.helperConnection?.remoteObjectProxyWithErrorHandler({ [weak self] (error) in
            if self?.applicationHasScreenshotHelper() ?? false {
                DispatchQueue.main.async {
                    self?.presentError(error)
                }
            }
        }) as? JSTScreenshotHelperProtocol {
            proxy.setNetworkDiscoveryEnabled(enabled)
            proxy.discoverDevices()
        }
    }
    
    internal func applicationXPCResetUI(with additionalItems: [NSMenuItem] = []) {
        #if APP_STORE
        if !applicationHasScreenshotHelper() {
            let downloadItem = NSMenuItem(title: NSLocalizedString("Download screenshot helper…", comment: "resetDevicesMenu"), action: #selector(actionRedirectToDownloadPage), keyEquivalent: "")
            downloadItem.target = self
            downloadItem.identifier = NSUserInterfaceItemIdentifier(rawValue: "")
            downloadItem.isEnabled = true
            downloadItem.state = .off
            devicesSubMenu.items = [ downloadItem ]
            return
        }
        #endif
        
        let emptyItem = NSMenuItem(title: NSLocalizedString("Connect to your iOS device via USB or network.", comment: "resetDevicesMenu"), action: nil, keyEquivalent: "")
        emptyItem.identifier = NSUserInterfaceItemIdentifier(rawValue: "")
        emptyItem.isEnabled = false
        emptyItem.state = .off
        devicesSubMenu.items = [ emptyItem ] + additionalItems
    }
    
    @objc internal func notifyXPCDiscoverDevices(_ sender: Any?) {
        guard let proxy = self.helperConnection?.remoteObjectProxyWithErrorHandler({ [weak self] (error) in
            if self?.applicationHasScreenshotHelper() ?? false {
                DispatchQueue.main.async {
                    self?.presentError(error)
                }
            }
        }) as? JSTScreenshotHelperProtocol else { return }
        proxy.discoverDevices()
    }
    
    
    // MARK: - Device Action: Take Screenshot
    
    @IBAction private func enableNetworkDiscoveryMenuItemTapped(_ sender: NSMenuItem) {
        let enabled = sender.state == .on
        sender.state = !enabled ? .on : .off
        UserDefaults.standard[.enableNetworkDiscovery] = !enabled
        applicationXPCSetup()
    }
    
    private func promiseProxyLookupDevice(_ proxy: JSTScreenshotHelperProtocol, by udid: String) -> Promise<[String: String]> {
        return Promise<[String: String]> { seal in
            after(.seconds(3)).done {
                seal.reject(XPCError.timeout)
            }
            proxy.lookupDevice(byUDID: udid) { (data, error) in
                if let error = error {
                    seal.reject(error)
                    return
                }
                seal.fulfill(try! PropertyListSerialization.propertyList(from: data!, options: [], format: nil) as! [String: String])
            }
        }
    }
    
    private func promiseProxyTakeScreenshot(_ proxy: JSTScreenshotHelperProtocol, by udid: String) -> Promise<Data> {
        return Promise<Data> { seal in
            after(.seconds(30)).done {
                seal.reject(XPCError.timeout)
            }
            proxy.takeScreenshot(byUDID: udid) { (data, error) in
                if let error = error {
                    seal.reject(error)
                    return
                }
                seal.fulfill(data!)
            }
        }
    }
    
    private func promiseSaveScreenshot(_ data: Data, to path: String) -> Promise<URL> {
        let picturesDirectoryURL = URL(fileURLWithPath: NSString(string: path).standardizingPath)
        return Promise<URL> { seal in
            after(.seconds(5)).done {
                seal.reject(XPCError.timeout)
            }
            do {
                var isDirectory: ObjCBool = false
                if !FileManager.default.fileExists(atPath: picturesDirectoryURL.path, isDirectory: &isDirectory) {
                    try FileManager.default.createDirectory(at: picturesDirectoryURL, withIntermediateDirectories: true, attributes: nil)
                }
                var picturesURL = picturesDirectoryURL
                picturesURL.appendPathComponent("screenshot_\(AppDelegate.screenshotDateFormatter.string(from: Date.init()))")
                picturesURL.appendPathExtension("png")
                try data.write(to: picturesURL)
                seal.fulfill(picturesURL)
            } catch {
                seal.reject(error)
            }
        }
    }
    
    private func promiseOpenDocument(at url: URL) -> Promise<Void> {
        return Promise<Void> { seal in
            after(.seconds(5)).done {
                seal.reject(XPCError.timeout)
            }
            NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { (document, documentWasAlreadyOpen, error) in
                if let error = error {
                    seal.reject(error)
                    return
                }
                seal.fulfill_()
            }
        }
    }
    
    @objc func takeScreenshot(_ sender: Any?) {
        guard !self.isTakingScreenshot else { return }
        self.isTakingScreenshot = true
        
        guard let picturesDirectoryPath: String = UserDefaults.standard[.screenshotSavingPath] else { return }
        guard let windowController = firstRespondingWindowController else { return }
        guard let proxy = self.helperConnection?.remoteObjectProxyWithErrorHandler({ [weak self] (error) in
            if self?.applicationHasScreenshotHelper() ?? false {
                DispatchQueue.main.async {
                    self?.presentError(error)
                }
            }
        }) as? JSTScreenshotHelperProtocol else { return }
        
        guard let selectedDeviceUDID = selectedDeviceUDID else {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("No device selected", comment: "takeScreenshot(_:)")
            alert.informativeText = NSLocalizedString("Select an iOS device from \"Devices\" menu.", comment: "devicesTakeScreenshotMenuItemTapped(_:)")
            alert.addButton(withTitle: NSLocalizedString("OK", comment: "takeScreenshot(_:)"))
            alert.alertStyle = .informational
            windowController.showSheet(alert) { [weak self] (resp) in
                self?.isTakingScreenshot = false
            }
            return
        }
        
        let loadingAlert = NSAlert()
        loadingAlert.addButton(withTitle: NSLocalizedString("Cancel", comment: "takeScreenshot(_:)"))
        loadingAlert.alertStyle = .informational
        loadingAlert.buttons.first?.isHidden = true
        let loadingIndicator = NSProgressIndicator(frame: CGRect(x: 0, y: 0, width: 24.0, height: 24.0))
        loadingIndicator.style = .spinning
        loadingIndicator.startAnimation(nil)
        loadingAlert.accessoryView = loadingIndicator
        
        firstly { () -> Promise<[String: String]> in
            loadingAlert.messageText = NSLocalizedString("Connect to device", comment: "takeScreenshot(_:)")
            loadingAlert.informativeText = String(format: NSLocalizedString("Establish connection to device \"%@\"…", comment: "takeScreenshot(_:)"), selectedDeviceUDID)
            windowController.showSheet(loadingAlert, completionHandler: nil)
            return self.promiseProxyLookupDevice(proxy, by: selectedDeviceUDID)
        }.then { [unowned self] (device) -> Promise<Data> in
            loadingAlert.messageText = NSLocalizedString("Wait for device", comment: "takeScreenshot(_:)")
            loadingAlert.informativeText = String(format: NSLocalizedString("Download screenshot from device \"%@\"…", comment: "takeScreenshot(_:)"), device["name"]!)
            return self.promiseProxyTakeScreenshot(proxy, by: device["udid"]!)
        }.then { [unowned self] (data) -> Promise<URL> in
            return self.promiseSaveScreenshot(data, to: picturesDirectoryPath)
        }.then { [unowned self] (url) -> Promise<Void> in
            windowController.showSheet(nil, completionHandler: nil)
            return self.promiseOpenDocument(at: url)
        }.catch { (error) in
            let alert = NSAlert(error: error)
            windowController.showSheet(alert, completionHandler: nil)
        }.finally { [weak self] in
            // do nothing
            self?.isTakingScreenshot = false
        }
    }
    
    @IBAction internal func devicesTakeScreenshotMenuItemTapped(_ sender: NSMenuItem) {
        takeScreenshot(sender)
    }
    
    
    // MARK: - Device Action: Select
    
    @objc private func actionDeviceItemTapped(_ sender: NSMenuItem) {
        selectDeviceSubMenuItem(sender)
    }
    
    private func selectDeviceSubMenuItem(_ sender: NSMenuItem?) {
        guard let identifier = sender?.identifier?.rawValue else {
            selectedDeviceUDID = nil
            return
        }
        guard identifier.lengthOfBytes(using: .utf8) > 0 else { return }
        let beginIdx = identifier.index(identifier.startIndex, offsetBy: AppDelegate.deviceIdentifierPrefix.lengthOfBytes(using: .utf8))
        let udid = String(identifier[beginIdx...])
        selectedDeviceUDID = udid
    }
    
    
    // MARK: - Device Action: Download Redirect
    
    #if APP_STORE
    @objc private func actionRedirectToDownloadPage() {
        NSWorkspace.shared.redirectToHelperPage()
    }
    #endif
    
    
    // MARK: - Device Menu Items
    
    internal func updateDevicesMenuItems() {
        devicesEnableNetworkDiscoveryMenuItem.state = UserDefaults.standard[.enableNetworkDiscovery] ? .on : .off
        devicesTakeScreenshotMenuItem.isEnabled = applicationHasScreenshotHelper()
    }
    
    internal func updateDevicesSubMenuItems() {
        let selectedDeviceIdentifier = "\(AppDelegate.deviceIdentifierPrefix)\(self.selectedDeviceUDID ?? "")"
        for item in devicesSubMenu.items {
            guard let deviceIdentifier = item.identifier?.rawValue else { continue }
            item.isEnabled = true
            item.state = deviceIdentifier == selectedDeviceIdentifier ? .on : .off
        }
        reloadDevicesSubMenuItems()
    }
    
    private func reloadDevicesSubMenuItems() {
        guard let proxy = self.helperConnection?.remoteObjectProxyWithErrorHandler({ [weak self] (error) in
            if self?.applicationHasScreenshotHelper() ?? false {
                DispatchQueue.main.async {
                    self?.presentError(error)
                }
            }
        }) as? JSTScreenshotHelperProtocol else { return }
        
        let selectedDeviceIdentifier = "\(AppDelegate.deviceIdentifierPrefix)\(self.selectedDeviceUDID ?? "")"
        DispatchQueue.global(qos: .default).async { [weak self] in
            proxy.discoveredDevices { (data, error) in
                guard let data = data else { return }
                guard let devices = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [[String: String]] else { return }
                
                DispatchQueue.main.async { [weak self] in
                    var items: [NSMenuItem] = []
                    for device in devices {
                        guard let deviceUDID = device["udid"], let deviceName = device["name"] else { continue }
                        // if self?.selectedDeviceUDID == nil { self?.selectedDeviceUDID = udid }
                        
                        let deviceIdentifier = "\(AppDelegate.deviceIdentifierPrefix)\(deviceUDID)"
                        let item = NSMenuItem(title: "\(deviceName) (\(deviceUDID))", action: #selector(self?.actionDeviceItemTapped(_:)), keyEquivalent: "")
                        item.identifier = NSUserInterfaceItemIdentifier(rawValue: deviceIdentifier)
                        item.tag = MainMenu.MenuItemTag.devices.rawValue
                        item.isEnabled = true
                        item.state = deviceIdentifier == selectedDeviceIdentifier ? .on : .off
                        if let deviceType = device["type"] {
                            switch deviceType {
                                case JSTDeviceTypeUSB:
                                    item.image = NSImage(named: "usb")
                                case JSTDeviceTypeNetwork:
                                    item.image = NSImage(systemSymbolName: "wifi", accessibilityDescription: "wifi")
                                case JSTDeviceTypeBonjour:
                                    item.image = NSImage(systemSymbolName: "bonjour", accessibilityDescription: "bonjour")
                                default:
                                    break
                            }
                        }
                        items.append(item)
                    }
                    
                    let separatorItem = NSMenuItem.separator()
                    let manuallyDiscoverItem = NSMenuItem(title: NSLocalizedString("Discover Devices", comment: "reloadDevicesSubMenuItems()"), action: #selector(self?.notifyXPCDiscoverDevices(_:)), keyEquivalent: "i")
                    manuallyDiscoverItem.keyEquivalentModifierMask = [.control]
                    manuallyDiscoverItem.toolTip = NSLocalizedString("Immediately broadcast a search for available devices on the LAN.", comment: "reloadDevicesSubMenuItems()")
                    
                    if items.count > 0 {
                        items += [separatorItem, manuallyDiscoverItem]
                        self?.devicesSubMenu.items = items
                    }
                    else {
                        self?.applicationXPCResetUI(with: [separatorItem, manuallyDiscoverItem])
                    }
                    
                    self?.devicesSubMenu.update()
                }
            }
        }
    }
    
}

