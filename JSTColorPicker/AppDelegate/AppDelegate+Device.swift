//
//  AppDelegate+Device.swift
//  JSTColorPicker
//
//  Created by Rachel on 6/8/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa
import OMGHTTPURLRQ
import PromiseKit
import SwiftBonjour


// MARK: - Bonjour Device

struct BonjourDevice: Equatable, Hashable {
    internal init(hostName: String, domain: String, name: String, port: Int, txtRecord: [String : String], ipAddresses: [String]) {
        self.hostName = hostName
        self.domain = domain
        self.name = name
        self.port = port
        self.txtRecord = txtRecord
        self.ipAddresses = ipAddresses
    }
    
    let hostName: String
    let domain: String
    let name: String
    let port: Int
    let txtRecord: [String: String]
    let ipAddresses: [String]
    
    internal init(netService: NetService) {
        self.domain = netService.domain
        self.name = netService.name
        self.hostName = netService.hostName ?? ""
        self.port = netService.port
        self.txtRecord = netService.txtRecordDictionary ?? [:]
        self.ipAddresses = netService.ipAddresses.map({ String(describing: $0) })
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(hostName)
        hasher.combine(domain)
        hasher.combine(name)
        hasher.combine(port)
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.hostName == rhs.hostName && lhs.domain == rhs.domain && lhs.name == rhs.name && lhs.port == rhs.port
    }
    
    static func unresolved(hostName: String) -> BonjourDevice {
        return BonjourDevice(hostName: hostName, domain: "", name: "", port: 0, txtRecord: [:], ipAddresses: [])
    }
    
    var isResolved: Bool {
        ipAddresses.count > 0
    }
}


// MARK: - XPC Connection

extension AppDelegate {
    
    private var selectedDeviceUDID: String?
    {
        get { UserDefaults.standard[.lastSelectedDeviceUDID]            }
        set { UserDefaults.standard[.lastSelectedDeviceUDID] = newValue }
    }
    
    private static let devicePrefixPaired: String = "device.paired."
    private static let devicePrefixBonjour: String = "device.bonjour."
    private static let deviceBonjourServicePort = 46952
    private static let deviceBonjourServiceType = ServiceType.tcp("http")
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
    
    
    // MARK: - XPC Functions
    
    internal func applicationXPCSetup() {
        applicationXPCDeactivate()
        
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
    
    internal func applicationXPCDeactivate() {
        self.helperConnection?.invalidate()
        self.helperConnection = nil
    }
    
    internal func applicationBonjourSetup() {
        applicationBonjourDeactivate()
        
        if isNetworkDiscoveryEnabled {
            let deviceBrowser = BonjourBrowser()
            
            deviceBrowser.serviceFoundHandler = { service in
                debugPrint("Bonjour service found", service)
            }
            
            deviceBrowser.serviceResolvedHandler = { [unowned self] result in
                debugPrint("Bonjour service resolved", result)
                switch result {
                    case let .success(service):
                        self.helperBonjourDevices.insert(BonjourDevice(netService: service))
                    case .failure(_):
                        break
                }
            }
            
            deviceBrowser.serviceRemovedHandler = { [unowned self] service in
                debugPrint("Bonjour service removed", service)
                if let serviceToRemove = self.helperBonjourDevices.first(
                    where: { $0.hostName == service.hostName && $0.name == service.name }
                ) {
                    self.helperBonjourDevices.remove(serviceToRemove)
                }
            }
            
            self.helperBonjourBrowser = deviceBrowser
        }
    }
    
    internal func applicationBonjourDeactivate() {
        self.helperBonjourBrowser?.stop()
        self.helperBonjourBrowser = nil
        self.helperBonjourDevices.removeAll()
    }
    
    @objc internal func applicationHelperDidBecomeAvailable(_ noti: Notification) {
        applicationXPCSetup()
        applicationBonjourSetup()
    }
    
    @objc internal func applicationHelperDidResignAvailable(_ noti: Notification) {
        applicationXPCDeactivate()
        applicationBonjourDeactivate()
        
        applicationResetDeviceUI()
    }
    
    internal func applicationXPCEstablish() {
        if let proxy = self.helperConnection?.remoteObjectProxyWithErrorHandler({ [weak self] (error) in
            if self?.applicationHasScreenshotHelper() ?? false {
                DispatchQueue.main.async {
                    self?.presentError(error)
                }
            }
        }) as? JSTScreenshotHelperProtocol
        {
            proxy.setNetworkDiscoveryEnabled(isNetworkDiscoveryEnabled)
            proxy.discoverDevices()
        }
    }
    
    internal func applicationBonjourEstablish() {
        if isNetworkDiscoveryEnabled {
            self.helperBonjourBrowser?.browse(type: AppDelegate.deviceBonjourServiceType, domain: "local.")
        }
    }
    
    internal func applicationResetDeviceUI(with additionalItems: [NSMenuItem] = []) {
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
    
    @objc internal func notifyDiscoverDevices(_ sender: Any?) {
        applicationXPCEstablish()
        applicationBonjourEstablish()
    }
    
    
    // MARK: - Device Action: Take Screenshot
    
    @IBAction private func enableNetworkDiscoveryMenuItemTapped(_ sender: NSMenuItem) {
        let enabled = sender.state == .on
        sender.state = !enabled ? .on : .off
        UserDefaults.standard[.enableNetworkDiscovery] = !enabled
        notifyDiscoverDevices(sender)
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
    
    typealias SocketAddress = (address: String, port: Int)
    
    private func promiseResolveBonjourDevice(byHostName hostName: String) -> Promise<BonjourDevice> {
        return Promise<BonjourDevice> { seal in
            if let device = self.helperBonjourDevices.first(where: { $0.hostName == hostName && $0.port == AppDelegate.deviceBonjourServicePort }) {
                seal.fulfill(device)
            } else {
                seal.fulfill(BonjourDevice.unresolved(hostName: hostName))
            }
        }
    }
    
    private func promiseResolveSocketAddress(ofDevice device: BonjourDevice) -> Promise<SocketAddress> {
        return Promise<SocketAddress> { seal in
            after(.seconds(3)).done {
                seal.reject(XPCError.timeout)
            }
            if device.isResolved {
                seal.fulfill((device.ipAddresses.first!, device.port))
            } else {
                DispatchQueue.global(qos: .userInitiated).async {
                    let addresses = Host(name: device.hostName).addresses
                    if addresses.count > 0, let firstAddress = addresses.filter({ !$0.contains(":") }).first
                    {
                        seal.fulfill((firstAddress, AppDelegate.deviceBonjourServicePort))
                    } else {
                        seal.reject(NetworkError.cannotResolveName(name: device.hostName))
                    }
                }
            }
        }
    }
    
    private func promiseFetchForegroundOrientation(fromSocketAddress socketAddress: SocketAddress) -> Promise<Int> {
        return Promise<Int> { seal in
            after(.seconds(10)).done {
                seal.reject(XPCError.timeout)
            }
            let urlString = "http://\(socketAddress.address):\(socketAddress.port)/device_front_orien"
            let rq = try! OMGHTTPURLRQ.post(urlString, nil) as URLRequest
            let task = helperSession.dataTask(.promise, with: rq)
            task.compactMap { (data: Data, _: URLResponse) in
                return try? JSONSerialization.jsonObject(with:data, options: []) as? [String: Any]
            }.done { json in
                if let orien = (json["data"] as? [String: Any])?["orien"] as? Int {
                    seal.fulfill(orien)
                } else {
                    seal.reject(CustomProtocolError.malformedResponse)
                }
            }.catch {
                seal.reject($0)
            }
        }
    }
    
    private func promiseDownloadScreenshot(fromSocketAddress socketAddress: SocketAddress) -> Promise<Data> {
        return Promise<Data> { seal in
            firstly { [unowned self] in
                self.promiseFetchForegroundOrientation(fromSocketAddress: socketAddress)
            }.then { [unowned self] orientation in
                self.promiseDownloadScreenshot(fromSocketAddress: socketAddress, withOrientation: orientation)
            }.done { data in
                seal.fulfill(data)
            }.catch {
                seal.reject($0)
            }
        }
    }
    
    private func promiseDownloadScreenshot(fromSocketAddress socketAddress: SocketAddress, withOrientation orientation: Int) -> Promise<Data> {
        return Promise<Data> { seal in
            after(.seconds(20)).done {
                seal.reject(XPCError.timeout)
            }
            let urlString = "http://\(socketAddress.address):\(socketAddress.port)/snapshot"
            let rq = try! OMGHTTPURLRQ.get(urlString, ["orient": orientation]) as URLRequest
            let task = self.helperSession.dataTask(.promise, with: rq)
            task.done { (data: Data, _: URLResponse) in
                seal.fulfill(data)
            }.catch {
                seal.reject($0)
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
    
    private static func checkUDIDOrHostName(_ string: String) -> Bool {
        return !string.contains(".")
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
        
        var dataPromise: Promise<Data>
        if AppDelegate.checkUDIDOrHostName(selectedDeviceUDID) {
            dataPromise = firstly { [unowned self] () -> Promise<[String: String]> in
                loadingAlert.messageText = NSLocalizedString("Connect to device", comment: "takeScreenshot(_:)")
                loadingAlert.informativeText = String(format: NSLocalizedString("Establish connection to device \"%@\"…", comment: "takeScreenshot(_:)"), selectedDeviceUDID)
                windowController.showSheet(loadingAlert, completionHandler: nil)
                return self.promiseProxyLookupDevice(proxy, by: selectedDeviceUDID)
            }.then { [unowned self] (device) -> Promise<Data> in
                loadingAlert.messageText = NSLocalizedString("Wait for device", comment: "takeScreenshot(_:)")
                loadingAlert.informativeText = String(format: NSLocalizedString("Download screenshot from device \"%@\"…", comment: "takeScreenshot(_:)"), device["name"]!)
                return self.promiseProxyTakeScreenshot(proxy, by: device["udid"]!)
            }
        } else {
            dataPromise = firstly { [unowned self] () -> Promise<BonjourDevice> in
                loadingAlert.messageText = NSLocalizedString("Connect to device", comment: "takeScreenshot(_:)")
                loadingAlert.informativeText = String(format: NSLocalizedString("Establish connection to device \"%@\"…", comment: "takeScreenshot(_:)"), selectedDeviceUDID)
                windowController.showSheet(loadingAlert, completionHandler: nil)
                return self.promiseResolveBonjourDevice(byHostName: selectedDeviceUDID)
            }.then { [unowned self] (device: BonjourDevice) -> Promise<SocketAddress> in
                loadingAlert.messageText = NSLocalizedString("Wait for device", comment: "takeScreenshot(_:)")
                loadingAlert.informativeText = String(format: NSLocalizedString("Download screenshot from device \"%@\"…", comment: "takeScreenshot(_:)"), device.name.isEmpty ? device.hostName : device.name)
                return self.promiseResolveSocketAddress(ofDevice: device)
            }.then { [unowned self] (sockAddr: SocketAddress) -> Promise<Data> in
                return self.promiseDownloadScreenshot(fromSocketAddress: sockAddr)
            }
        }
        
        dataPromise.then { [unowned self] (data) -> Promise<URL> in
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
        guard let identifier = sender?.identifier?.rawValue.components(separatedBy: ".").dropFirst(2).joined(separator: ".") else {
            selectedDeviceUDID = nil
            return
        }
        selectedDeviceUDID = identifier
    }
    
    
    // MARK: - Device Action: Download Redirect
    
    #if APP_STORE
    @objc private func actionRedirectToDownloadPage() {
        NSWorkspace.shared.redirectToHelperPage()
    }
    #endif
    
    
    // MARK: - Device Menu Items
    
    internal func updateDevicesMenuItems() {
        devicesEnableNetworkDiscoveryMenuItem.state = isNetworkDiscoveryEnabled ? .on : .off
        devicesTakeScreenshotMenuItem.isEnabled = applicationHasScreenshotHelper()
    }
    
    internal func updateDevicesSubMenuItems() {
        for item in devicesSubMenu.items {
            guard let deviceIdentifier = item.identifier?.rawValue.components(separatedBy: ".").dropFirst(2).joined(separator: ".") else { continue }
            item.isEnabled = true
            item.state = deviceIdentifier == self.selectedDeviceUDID ? .on : .off
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
        
        
        DispatchQueue.global(qos: .default).async { [weak self] in
            proxy.discoveredDevices { [weak self] (data, error) in
                guard let data = data else { return }
                guard let pairedDevices = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [[String: String]],
                      let pairedItems = self?.menuItemsForPairedDevices(pairedDevices),
                      let bonjourDevices = self?.helperBonjourDevices,
                      let bonjourItems = self?.menuItemsForBonjourDevices(Array(bonjourDevices))
                else { return }
                
                DispatchQueue.main.async { [weak self] in
                    
                    var items = [NSMenuItem]()
                    
                    items += pairedItems
                        .sorted(by: { $0.title.localizedStandardCompare($1.title) == .orderedAscending })
                    if pairedItems.count > 0 && bonjourItems.count > 0 {
                        items += [NSMenuItem.separator()]
                    }
                    items += bonjourItems
                        .sorted(by: { $0.title.localizedStandardCompare($1.title) == .orderedAscending })
                    
                    let manuallyDiscoverItem = NSMenuItem(title: NSLocalizedString("Discover Devices", comment: "reloadDevicesSubMenuItems()"), action: #selector(self?.notifyDiscoverDevices(_:)), keyEquivalent: "i")
                    manuallyDiscoverItem.keyEquivalentModifierMask = [.control]
                    manuallyDiscoverItem.toolTip = NSLocalizedString("Immediately broadcast a search for available devices on the LAN.", comment: "reloadDevicesSubMenuItems()")
                    
                    if items.count > 0 {
                        items += [NSMenuItem.separator(), manuallyDiscoverItem]
                        self?.devicesSubMenu.items = items
                    }
                    else {
                        self?.applicationResetDeviceUI(with: [NSMenuItem.separator(), manuallyDiscoverItem])
                    }
                    
                    self?.devicesSubMenu.update()
                }
            }
        }
    }
    
    private func menuItemsForPairedDevices(_ devices: [[String: String]]) -> [NSMenuItem] {
        let selectedDeviceIdentifier = "\(AppDelegate.devicePrefixPaired)\(self.selectedDeviceUDID ?? "")"
        var items: [NSMenuItem] = []
        
        for device in devices {
            guard let deviceUDID = device["udid"], let deviceName = device["name"] else { continue }
            // if self?.selectedDeviceUDID == nil { self?.selectedDeviceUDID = udid }
            
            let deviceIdentifier = "\(AppDelegate.devicePrefixPaired)\(deviceUDID)"
            let item = NSMenuItem(title: "\(deviceName) (\(deviceUDID))", action: #selector(self.actionDeviceItemTapped(_:)), keyEquivalent: "")
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
        
        return items
    }
    
    private func menuItemsForBonjourDevices(_ devices: [BonjourDevice]) -> [NSMenuItem] {
        let selectedDeviceIdentifier = "\(AppDelegate.devicePrefixBonjour)\(self.selectedDeviceUDID ?? "")"
        var items: [NSMenuItem] = []
        
        // FIXME: XXTouch Compatible
        for device in devices.filter({ $0.port == AppDelegate.deviceBonjourServicePort }) {
            let deviceIdentifier = "\(AppDelegate.devicePrefixBonjour)\(device.hostName)"
            let item = NSMenuItem(title: "\(device.name) (\(device.ipAddresses.first ?? ""))", action: #selector(self.actionDeviceItemTapped(_:)), keyEquivalent: "")
            item.identifier = NSUserInterfaceItemIdentifier(rawValue: deviceIdentifier)
            item.tag = MainMenu.MenuItemTag.devices.rawValue
            item.isEnabled = true
            item.state = deviceIdentifier == selectedDeviceIdentifier ? .on : .off
            item.image = NSImage(systemSymbolName: "bonjour", accessibilityDescription: "bonjour")
            
            items.append(item)
        }
        
        return items
    }
    
}

