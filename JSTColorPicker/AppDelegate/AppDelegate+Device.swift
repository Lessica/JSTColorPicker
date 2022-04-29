//
//  AppDelegate+Device.swift
//  JSTColorPicker
//
//  Created by Darwin on 6/8/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa
import OMGHTTPURLRQ
import PromiseKit
import SwiftBonjour
import PMKFoundation


// MARK: - XPC Connection

extension AppDelegate {
    
    private var selectedDeviceUniqueIdentifier: String?
    {
        get { UserDefaults.standard[.lastSelectedDeviceUDID]            }
        set { UserDefaults.standard[.lastSelectedDeviceUDID] = newValue }
    }
    
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
    
    static let applicationHelperConnectionDidInvalidatedNotification = Notification.Name("AppDelegate.applicationHelperConnectionDidInvalidatedNotification")
    static let applicationHelperConnectionDidInterruptedNotification = Notification.Name("AppDelegate.applicationHelperConnectionDidInterruptedNotification")
    
    
    // MARK: - XPC Functions
    
    internal func applicationXPCSetup(deactivate: Bool) {
        if deactivate {
            applicationXPCDeactivate()
        }
        
        if applicationCheckScreenshotHelper().exists {
#if APP_STORE
            let connectionToService = NSXPCConnection(machServiceName: kJSTColorPickerHelperBundleIdentifier)
#else
            let connectionToService = NSXPCConnection(serviceName: kJSTScreenshotHelperBundleIdentifier)
#endif
            
            connectionToService.interruptionHandler = { [weak self] in
                NotificationCenter.default.post(
                    name: AppDelegate.applicationHelperConnectionDidInterruptedNotification,
                    object: self
                )
            }
            connectionToService.invalidationHandler = { [weak self] in
                NotificationCenter.default.post(
                    name: AppDelegate.applicationHelperConnectionDidInvalidatedNotification,
                    object: self
                )
                self?.helperConnectionInvalidatedManually = false
            }  // <- error occurred

            connectionToService.remoteObjectInterface = NSXPCInterface(with: JSTScreenshotHelperProtocol.self)
            connectionToService.resume()
            
            self.helperConnection = connectionToService
        }
    }
    
    internal func applicationXPCDeactivate() {
        helperConnectionInvalidatedManually = true
        helperConnection?.invalidate()
        helperConnection = nil
    }
    
    internal func applicationBonjourSetup(deactivate: Bool) {
        if deactivate {
            applicationBonjourDeactivate()
        }
        
        if applicationCheckScreenshotHelper().exists && isNetworkDiscoveryEnabled
        {
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
        helperBonjourBrowser?.stop()
        helperBonjourBrowser = nil
        helperBonjourDevices.removeAll()
    }
    
    @objc internal func applicationHelperDidBecomeAvailable(_ noti: Notification) {
        applicationXPCSetup(deactivate: true)
        applicationBonjourSetup(deactivate: true)
        
        applicationXPCReloadDevices()
        applicationBonjourReloadDevices()
    }
    
    @objc internal func applicationHelperDidResignAvailable(_ noti: Notification) {
        applicationXPCDeactivate()
        applicationBonjourDeactivate()
        
        applicationResetDeviceUI()
    }
    
#if APP_STORE
    @objc internal func applicationHelperConnectionFailure(_ noti: Notification) {
        guard !helperConnectionInvalidatedManually && applicationCheckScreenshotHelper().exists
        else {
            return
        }
        if noti.name == AppDelegate.applicationHelperConnectionDidInterruptedNotification {
            // Crash (including not compatible), or killed by user
            DispatchQueue.main.async { [unowned self] in
                self.presentHelperConnectionFailureError(XPCError.interrupted)
            }
        } else if noti.name == AppDelegate.applicationHelperConnectionDidInvalidatedNotification {
            // Helper connection may be invalidated by system sometimes…
        }
    }
#endif
    
    internal func applicationXPCReloadDevices() {
        let isNetworkDiscoveryEnabled = isNetworkDiscoveryEnabled
        promiseXPCProxy()
            .then { [unowned self] proxy -> Promise<Data> in
                proxy.setNetworkDiscoveryEnabled(isNetworkDiscoveryEnabled)
                proxy.discoverDevices()
                return self.promiseXPCServiceInfo(proxy)
            }
            .then { [unowned self] data in
                return self.promiseXPCParseResponse(data)
            }
            .then { [unowned self] infoDictionary in
                return self.promiseXPCServiceVersion(infoDictionary)
            }
            .then { [unowned self] version -> Promise<Void> in
#if APP_STORE
                if let mainVersion = Bundle.main.bundleVersion, version.isVersion(lessThan: mainVersion) {
                    if self.screenshotHelperState != .outdated {
                        self.screenshotHelperState = .outdated
                    }
                } else {
                    if self.screenshotHelperState != .latest {
                        self.screenshotHelperState = .latest
                    }
                }
#endif
                return self.promiseVoid
            }
            .catch { [unowned self] err in
                if self.applicationCheckScreenshotHelper().exists {
                    DispatchQueue.main.async {
                        self.presentError(err)
                    }
                }
            }
    }
    
    internal func applicationBonjourReloadDevices() {
        if isNetworkDiscoveryEnabled {
            self.helperBonjourBrowser?.browse(type: AppDelegate.deviceBonjourServiceType, domain: "local.")
        }
    }
    
    internal var manuallyDiscoverItem: NSMenuItem {
        let item = NSMenuItem(title: NSLocalizedString("Discover Devices", comment: "reloadDevicesSubMenuItems()"), action: #selector(notifyDiscoverDevices(_:)), keyEquivalent: "i")
        item.keyEquivalentModifierMask = [.control]
        item.identifier = NSUserInterfaceItemIdentifier(rawValue: "discover-devices")
        item.toolTip = NSLocalizedString("Immediately broadcast a search for available devices on the LAN.", comment: "reloadDevicesSubMenuItems()")
        return item
    }
    
    #if APP_STORE
    internal var updateScreenshotHelperItem: NSMenuItem {
        let updateItem = NSMenuItem(title: NSLocalizedString("Update screenshot helper…", comment: "reloadDevicesSubMenuItems()"), action: #selector(actionRedirectToDownloadPage), keyEquivalent: "")
        updateItem.target = self
        updateItem.identifier = NSUserInterfaceItemIdentifier(rawValue: "")
        updateItem.isEnabled = true
        updateItem.state = .off
        return updateItem
    }
    #endif
    
    internal var additionalItemGroup: [NSMenuItem] {
        var additionalItems = [NSMenuItem](arrayLiteral: NSMenuItem.separator(), manuallyDiscoverItem)
        #if APP_STORE
        if applicationCheckScreenshotHelper() != .latest {
            additionalItems.append(updateScreenshotHelperItem)
        }
        #endif
        return additionalItems
    }
    
    internal func applicationResetDeviceUI() {
        internalApplicationResetDeviceUI(withAdditionalItems: additionalItemGroup)
    }
    
    private func internalApplicationResetDeviceUI(withAdditionalItems additionalItems: [NSMenuItem]) {
        #if APP_STORE
        if applicationCheckScreenshotHelper() == .missing {
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
    
    @IBAction internal func notifyDiscoverDevices(_ sender: Any?) {
        applicationXPCReloadDevices()
        applicationBonjourReloadDevices()
    }
    
    
    // MARK: - Device Action: Take Screenshot
    
    @IBAction private func enableNetworkDiscoveryMenuItemTapped(_ sender: NSMenuItem) {
        let enabled = sender.state == .on
        sender.state = !enabled ? .on : .off
        UserDefaults.standard[.enableNetworkDiscovery] = !enabled
        notifyDiscoverDevices(sender)
    }
    
    private func promiseProxyLookupDevice(_ proxy: JSTScreenshotHelperProtocol, byHostName hostName: String) -> Promise<Data> {
        return Promise<Data> { seal in
            after(.seconds(3)).done {
                seal.reject(XPCError.timeout)
            }
            guard let udid = hostName.split(separator: ".").compactMap({ String($0) }).last else {
                seal.reject(XPCError.invalidDeviceHandler(handler: hostName))
                return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                proxy.lookupDevice(byUDID: udid) { (data, error) in
                    if let error = error {
                        seal.reject(error)
                    } else if let data = data {
                        seal.fulfill(data)
                    }
                }
            }
        }
    }
    
    private func promiseProxyTakeScreenshot(_ proxy: JSTScreenshotHelperProtocol, byHostName hostName: String) -> Promise<Data> {
        return Promise<Data> { seal in
            after(.seconds(60)).done {
                seal.reject(XPCError.timeout)
            }
            guard let udid = hostName.split(separator: ".").compactMap({ String($0) }).last else {
                seal.reject(XPCError.invalidDeviceHandler(handler: hostName))
                return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                proxy.takeScreenshot(byUDID: udid) { (data, error) in
                    if let error = error {
                        seal.reject(error)
                    } else if let data = data {
                        seal.fulfill(data)
                    }
                }
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
            let task = self.helperURLSession.dataTask(.promise, with: rq)
            task.compactMap { (data: Data, _: URLResponse) in
                return try? JSONSerialization.jsonObject(with:data, options: []) as? [String: Any]
            }.done { json in
                if let orien = (json["data"] as? [String: Any])?["orien"] as? Int {
                    seal.fulfill(orien)
                } else {
                    seal.reject(XPCError.malformedResponse)
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
            after(.seconds(60)).done {
                seal.reject(XPCError.timeout)
            }
            let urlString = "http://\(socketAddress.address):\(socketAddress.port)/snapshot"
            let rq = try! OMGHTTPURLRQ.get(urlString, ["orient": orientation]) as URLRequest
            let task = self.helperURLSession.dataTask(.promise, with: rq)
            task.done { data, _ in
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
            ScreenshotController.shared.openDocument(withContentsOf: url, display: true) { (document, documentWasAlreadyOpen, error) in
                if let error = error {
                    seal.reject(error)
                    return
                }
                seal.fulfill_()
            }
        }
    }
    
    @objc func takeScreenshot(_ sender: Any?) {
        guard let windowController = firstRespondingWindowController
        else {
            return
        }
        
        guard let picturesDirectoryPath: String = UserDefaults.standard[.screenshotSavingPath]
        else {
            return
        }
        
        guard self.modalState == .idle else { return }
        self.modalState = .takeScreenshot
        
        guard let selectedIdentifier = selectedDeviceUniqueIdentifier else {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("No device selected", comment: "takeScreenshot(_:)")
            alert.informativeText = NSLocalizedString("Select an iOS device from “Devices” menu.", comment: "devicesTakeScreenshotMenuItemTapped(_:)")
            alert.addButton(withTitle: NSLocalizedString("OK", comment: "takeScreenshot(_:)"))
            alert.alertStyle = .informational
            windowController.showSheet(alert) { [unowned self] (resp) in
                self.modalState = .idle
            }
            return
        }
        
        let loadingAlert = NSAlert()
        loadingAlert.addButton(withTitle: NSLocalizedString("Cancel", comment: "takeScreenshot(_:)"))
        loadingAlert.alertStyle = .informational
        loadingAlert.buttons.first?.isHidden = true
        let loadingIndicator = NSProgressIndicator(frame: CGRect(x: 0, y: 0, width: 24.0, height: 24.0))
        loadingIndicator.style = .spinning
        loadingIndicator.sizeToFit()
        loadingIndicator.startAnimation(nil)
        loadingAlert.accessoryView = loadingIndicator
        
        var partialDeviceDict: [String: String]?
        var dataPromise: Promise<Data>
        if selectedIdentifier.hasPrefix(PairedDevice.uniquePrefix) {
            dataPromise = promiseXPCProxy()
                .then { [unowned self] (proxy) -> Promise<(JSTScreenshotHelperProtocol, Data)> in
                    loadingAlert.messageText = NSLocalizedString("Connect to device", comment: "takeScreenshot(_:)")
                    loadingAlert.informativeText = String(format: NSLocalizedString("Establish connection to device “%@”…", comment: "takeScreenshot(_:)"), selectedIdentifier)
                    windowController.showSheet(loadingAlert) { resp in
                        // TODO: cancel connection
                    }
                    return self.promiseProxyLookupDevice(proxy, byHostName: selectedIdentifier).map { (proxy, $0) }
                }
                .then { [unowned self] (proxy, data) -> Promise<(JSTScreenshotHelperProtocol, [String: String])> in
                    return self.promiseXPCParseResponse(data).map { (proxy, $0) }
                }
                .then { [unowned self] (proxy, deviceDict) -> Promise<Data> in
                    partialDeviceDict = deviceDict
                    loadingAlert.messageText = NSLocalizedString("Wait for device", comment: "takeScreenshot(_:)")
                    loadingAlert.informativeText = String(format: NSLocalizedString("Download screenshot from device “%@”…", comment: "takeScreenshot(_:)"), deviceDict["name"]!)
                    return self.promiseProxyTakeScreenshot(proxy, byHostName: deviceDict["udid"]!)
                }
        }
        else if selectedIdentifier.hasPrefix(BonjourDevice.uniquePrefix) {
            dataPromise = firstly { [unowned self] () -> Promise<BonjourDevice> in
                loadingAlert.messageText = NSLocalizedString("Connect to device", comment: "takeScreenshot(_:)")
                loadingAlert.informativeText = String(format: NSLocalizedString("Establish connection to device “%@”…", comment: "takeScreenshot(_:)"), selectedIdentifier)
                windowController.showSheet(loadingAlert) { resp in
                    // TODO: cancel connection or download
                }
                return self.promiseResolveBonjourDevice(byHostName: selectedIdentifier)
            }.then { [unowned self] (device: BonjourDevice) -> Promise<SocketAddress> in
                loadingAlert.messageText = NSLocalizedString("Wait for device", comment: "takeScreenshot(_:)")
                loadingAlert.informativeText = String(format: NSLocalizedString("Download screenshot from device “%@”…", comment: "takeScreenshot(_:)"), device.name.isEmpty ? device.hostName : device.name)
                return self.promiseResolveSocketAddress(ofDevice: device)
            }.then { [unowned self] (sockAddr: SocketAddress) -> Promise<Data> in
                return self.promiseDownloadScreenshot(fromSocketAddress: sockAddr)
            }
        }
        else {
            dataPromise = Promise<Data> { seal in
                seal.reject(XPCError.invalidDeviceHandler(handler: selectedIdentifier))
            }
        }
        
        dataPromise.then { [unowned self] data -> Promise<URL> in
            return self.promiseSaveScreenshot(data, to: picturesDirectoryPath)
        }.then { [unowned self] url -> Promise<Void> in
            windowController.showSheet(nil, completionHandler: nil)
            return self.promiseOpenDocument(at: url)
        }.catch(policy: .allErrors, { [unowned self] err in
            if self.applicationCheckScreenshotHelper().exists {
                DispatchQueue.main.async {
                    let alert = NSAlert(error: err)
                    let nsErr = err as NSError
                    
                    var hasRetryButton = false
                    var hasDownloadButton = false
                    if CommandError.isRecoverableCommandErrorCode(nsErr.code) {
                        alert.addButton(withTitle: NSLocalizedString("Retry", comment: "takeScreenshot(_:)"))
                        hasRetryButton = true
                    } else if nsErr.code == CommandError.missingMountResources.errorCode {
                        alert.addButton(withTitle: NSLocalizedString("Download", comment: "takeScreenshot(_:)"))
                        hasDownloadButton = true
                    }
                    let cancelButton = alert.addButton(withTitle: NSLocalizedString("Dismiss", comment: "takeScreenshot(_:)"))
                    cancelButton.keyEquivalent = "\u{1b}"
                    windowController.showSheet(alert) { resp in
                        if hasRetryButton && resp == .alertFirstButtonReturn
                        {
                            self.takeScreenshot(sender)
                        }
                        if let partialDeviceDict = partialDeviceDict,
                           hasDownloadButton && resp == .alertFirstButtonReturn
                        {
                            self.downloadDeviceSupport(sender, forDeviceDictionary: partialDeviceDict)
                        }
                    }
                }
            }
        }).finally({ [unowned self] in
            // do nothing
            self.modalState = .idle
        })
    }
    
    @IBAction internal func devicesTakeScreenshotMenuItemTapped(_ sender: NSMenuItem) {
        takeScreenshot(sender)
    }
    
    
    // MARK: - Device Action: Select
    
    @objc private func actionDeviceItemTapped(_ sender: NSMenuItem) {
        selectDeviceSubMenuItem(sender)
    }
    
    private func selectDeviceSubMenuItem(_ sender: NSMenuItem?) {
        guard let deviceModel = sender?.representedObject as? Device else {
            selectedDeviceUniqueIdentifier = nil
            return
        }
        selectedDeviceUniqueIdentifier = deviceModel.uniqueIdentifier
    }
    
    
    // MARK: - Device Action: Download Redirect
    
    #if APP_STORE
    @objc internal func actionRedirectToDownloadPage() {
        NSWorkspace.shared.redirectToHelperPage()
    }
    #endif
    
    
    // MARK: - Device Menu Items
    
    internal func updateDevicesMenuItems(_ menu: NSMenu) {
        devicesEnableNetworkDiscoveryMenuItem.state = isNetworkDiscoveryEnabled ? .on : .off
        devicesTakeScreenshotMenuItem.isEnabled = applicationCheckScreenshotHelper().exists
    }
    
    internal func updateDevicesSubMenuItems(_ menu: NSMenu) {
        for item in devicesSubMenu.items {
            guard let deviceModel = item.representedObject as? Device else { continue }
            item.isEnabled = true
            item.state = deviceModel.uniqueIdentifier == self.selectedDeviceUniqueIdentifier ? .on : .off
        }
        
        reloadDevicesSubMenuItems()
    }
    
    private func promiseDiscoveredDevices(_ proxy: JSTScreenshotHelperProtocol) -> Promise<Data> {
        return Promise<Data> { seal in
            after(.seconds(3)).done {
                seal.reject(XPCError.timeout)
            }
            DispatchQueue.global(qos: .userInitiated).async {
                proxy.discoveredDevices { data, err in
                    if let err = err {
                        seal.reject(err)
                    } else if let data = data {
                        seal.fulfill(data)
                    }
                }
            }
        }
    }
    
    private func reloadDevicesSubMenuItems() {
        promiseXPCProxy()
            .then { [unowned self] proxy in
                return self.promiseDiscoveredDevices(proxy)
            }
            .then { [unowned self] data -> Promise<[[String: String]]> in
                return self.promiseXPCParseResponse(data)
            }
            .then { [unowned self] pairedDevices -> Promise<Void> in
                let pairedItems = self.menuItemsForPairedDevices(pairedDevices)
                let bonjourDevices = self.helperBonjourDevices
                let bonjourItems = self.menuItemsForBonjourDevices(Array(bonjourDevices))
                
                DispatchQueue.main.async {
                    var items = [NSMenuItem]()
                    
                    items += pairedItems
                        .sorted(by: { $0.title.localizedStandardCompare($1.title) == .orderedAscending })
                    if pairedItems.count > 0 && bonjourItems.count > 0 {
                        items += [NSMenuItem.separator()]
                    }
                    items += bonjourItems
                        .sorted(by: { $0.title.localizedStandardCompare($1.title) == .orderedAscending })
                    
                    if items.count > 0 {
                        items += self.additionalItemGroup
                        self.devicesSubMenu.items = items
                    }
                    else {
                        items += self.additionalItemGroup
                        self.internalApplicationResetDeviceUI(withAdditionalItems: items)
                    }
                    
                    self.devicesSubMenu.update()
                }
                
                return self.promiseVoid
            }
            .catch { _ in }
    }
    
    private func menuItemsForPairedDevices(_ deviceDicts: [[String: String]]) -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        
        for deviceDict in deviceDicts {
            guard let deviceUDID = deviceDict["udid"],
                  let deviceName = deviceDict["name"]
            else { continue }
            
            let deviceModel = PairedDevice(
                udid: deviceUDID,
                name: deviceName,
                type: deviceDict["type"] ?? "",
                model: deviceDict["model"] ?? "",
                version: deviceDict["version"] ?? ""
            )
            
            let item = NSMenuItem(title: "\(deviceModel.title) (\(deviceModel.subtitle))", action: #selector(self.actionDeviceItemTapped(_:)), keyEquivalent: "")
            item.identifier = NSUserInterfaceItemIdentifier(rawValue: deviceModel.uniqueIdentifier)
            item.tag = MainMenu.MenuItemTag.devices.rawValue
            item.isEnabled = true
            item.state = deviceModel.uniqueIdentifier == self.selectedDeviceUniqueIdentifier ? .on : .off
            
            var itemToolTip = String(
                format: NSLocalizedString("UDID: %@\nDevice Name: %@", comment: "menuItemsForPairedDevices(_:)"),
                deviceUDID, deviceName
            )
            
            if !deviceModel.type.isEmpty {
                itemToolTip += String(format: NSLocalizedString("\nConnection: %@", comment: "menuItemsForPairedDevices(_:)"), deviceModel.type)
            }
            
            if !deviceModel.model.isEmpty {
                itemToolTip += String(format: NSLocalizedString("\nProduct Type: %@", comment: "menuItemsForPairedDevices(_:)"), deviceModel.model)
            }
            
            if !deviceModel.version.isEmpty {
                itemToolTip += String(format: NSLocalizedString("\nProduct Version: %@", comment: "menuItemsForPairedDevices(_:)"), deviceModel.version)
            }
            
            item.toolTip = itemToolTip
            
            let lowercasedModel = deviceModel.model.lowercased()
            
            // Apple Device (Fancy Icons)
            if lowercasedModel.hasPrefix("appletv") {
                item.image = NSImage(systemSymbolName: "appletv.fill", accessibilityDescription: "appletv.fill")
            }
            else if lowercasedModel.hasPrefix("iphone") {
                item.image = NSImage(systemSymbolName: "iphone", accessibilityDescription: "iphone")
            }
            else if lowercasedModel.hasPrefix("ipad") {
                item.image = NSImage(systemSymbolName: "ipad", accessibilityDescription: "ipad")
            }
            else if lowercasedModel.hasPrefix("ipod") {
                item.image = NSImage(systemSymbolName: "ipodtouch", accessibilityDescription: "ipodtouch")
            }
            
            // Android Device (USB)
            else {
                switch deviceModel.type {
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
            
            item.representedObject = deviceModel
            items.append(item)
        }
        
        return items
    }
    
    private func menuItemsForBonjourDevices(_ devices: [BonjourDevice]) -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        
        // FIXME: XXTouch Compatible
        for deviceModel in devices.filter({ $0.port == AppDelegate.deviceBonjourServicePort }) {
            let item = NSMenuItem(title: "\(deviceModel.title) (\(deviceModel.subtitle))", action: #selector(self.actionDeviceItemTapped(_:)), keyEquivalent: "")
            item.identifier = NSUserInterfaceItemIdentifier(rawValue: deviceModel.uniqueIdentifier)
            item.tag = MainMenu.MenuItemTag.devices.rawValue
            item.isEnabled = true
            item.state = deviceModel.uniqueIdentifier == self.selectedDeviceUniqueIdentifier ? .on : .off
            item.image = NSImage(systemSymbolName: "bonjour", accessibilityDescription: "bonjour")
            item.representedObject = deviceModel
            
            items.append(item)
        }
        
        return items
    }
    
}

