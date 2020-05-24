//
//  AppDelegate.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/12/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa
import PromiseKit
import MASPreferences
import ServiceManagement

enum XPCError: LocalizedError {
    case timeout
    
    var failureReason: String? {
        switch self {
        case .timeout:
            return NSLocalizedString("Connection timeout.", comment: "XPCError")
        }
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    public var tabService: TabService?
    public var helperConnection: NSXPCConnection?
    @IBOutlet weak var menu: NSMenu!
    @IBOutlet weak var mainMenu: NSMenu!
    
    public let gridController = GridWindowController.newGrid()
    private lazy var preferencesController: NSWindowController = {
        let generalController = GeneralController()
        let folderController = FolderController()
        let advancedController = AdvancedController()
        let controller = PreferencesController(viewControllers: [generalController, folderController, advancedController], title: NSLocalizedString("Preferences", comment: "PreferencesController"))
        return controller
    }()
    
    
    // MARK: - Application Events
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        if objc_getClass("SUAppcast") != nil {
            checkForUpdatesItem.isHidden = false
        }
        
        let initialValues: [UserDefaults.Key: Any?] = [
            
            .AppleMomentumScrollSupported: true,
            
            .toggleTableColumnID: true,
            .toggleTableColumnDelay: false,
            .toggleTableColumnSimilarity: false,
            .toggleTableColumnDescription: true,
            
            .togglePaneViewPreview: true,
            .togglePaneViewInspector: false,
            .togglePaneViewInformation: true,
            
            .useAlternativeAreaRepresentation: false,
            
            .enableNetworkDiscovery: false,
            
            .enableForceTouch: true,
            .drawSceneBackground: false,
            .drawGridsInScene: true,
            .drawRulersInScene: true,
            .drawBackgroundInGridView: false,
            .drawAnnotatorsInGridView: false,
            .hideGridsWhenResize: true,
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
        
        applicationResetDevicesSubMenu()
        applicationEstablishXPCConnection()
        applicationSetupScreenshotHelper()
        
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        self.helperConnection?.invalidate()
    }
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        let windowController = applicationReinitializeTabService()
        windowController.showWindow(self)
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        guard url.scheme == "jstcolorpicker" else { return }
        if url.host == "activate" {
            applicationEstablishXPCConnection()
        }
    }
    
    fileprivate func applicationEstablishXPCConnection() {
        if let prevConnection = self.helperConnection {
            prevConnection.invalidate()
            self.helperConnection = nil
        }
        
        #if SANDBOXED
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
    
    public func applicationReinitializeTabService() -> WindowController {
        let windowController = WindowController.newEmptyWindow()
        tabService = TabService(initialWindowController: windowController)
        return windowController
    }
    
    
    // MARK: - Preferences Actions
    
    @IBAction func preferencesItemTapped(_ sender: Any?) {
        preferencesController.showWindow(sender)
    }
    
    
    // MARK: - Compare Actions
    
    @IBOutlet weak var fileMenu: NSMenu!
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
    
    @IBOutlet weak var devicesEnableNetworkDiscoveryMenuItem: NSMenuItem!
    @IBOutlet weak var devicesTakeScreenshotMenuItem: NSMenuItem!
    @IBOutlet weak var devicesMenu: NSMenu!
    @IBOutlet weak var devicesSubMenu: NSMenu!
    
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
        let enabled = sender.state == .on
        sender.state = !enabled ? .on : .off
        UserDefaults.standard[.enableNetworkDiscovery] = !enabled
        applicationSetupScreenshotHelper()
    }
    
    fileprivate func promiseProxyLookupDevice(_ proxy: JSTScreenshotHelperProtocol, by udid: String) -> Promise<[String: String]> {
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
    
    fileprivate func promiseProxyTakeScreenshot(_ proxy: JSTScreenshotHelperProtocol, by udid: String) -> Promise<Data> {
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
    
    fileprivate func promiseSaveScreenshot(_ data: Data, to path: String) -> Promise<URL> {
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
            } catch let error {
                seal.reject(error)
            }
        }
    }
    
    fileprivate func promiseOpenDocument(at url: URL) -> Promise<Void> {
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
    
    fileprivate var isTakingScreenshot: Bool = false
    
    @IBAction func devicesTakeScreenshotMenuItemTapped(_ sender: Any?) {
        
        guard !self.isTakingScreenshot else { return }
        self.isTakingScreenshot = true
        
        guard let picturesDirectoryPath: String = UserDefaults.standard[.screenshotSavingPath] else { return }
        guard let windowController = tabService?.firstRespondingWindow?.windowController as? WindowController else { return }
        guard let proxy = self.helperConnection?.remoteObjectProxyWithErrorHandler({ (error) in
            debugPrint(error)
        }) as? JSTScreenshotHelperProtocol else { return }
        
        guard let selectedDeviceUDID = selectedDeviceUDID else {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("No device selected", comment: "screenshotItemTapped(_:)")
            alert.informativeText = NSLocalizedString("Select an iOS device from \"Devices\" menu.", comment: "screenshotItemTapped(_:)")
            alert.addButton(withTitle: NSLocalizedString("OK", comment: "screenshotItemTapped(_:)"))
            alert.alertStyle = .warning
            windowController.showSheet(alert) { [weak self] (resp) in
                self?.isTakingScreenshot = false
            }
            return
        }
        
        let loadingAlert = NSAlert()
        loadingAlert.addButton(withTitle: NSLocalizedString("Cancel", comment: "screenshotItemTapped(_:)"))
        loadingAlert.alertStyle = .informational
        loadingAlert.buttons.first?.isHidden = true
        let loadingIndicator = NSProgressIndicator(frame: CGRect(x: 0, y: 0, width: 24.0, height: 24.0))
        loadingIndicator.style = .spinning
        loadingIndicator.startAnimation(nil)
        loadingAlert.accessoryView = loadingIndicator
        
        firstly { () -> Promise<[String: String]> in
            loadingAlert.messageText = NSLocalizedString("Connect to device", comment: "screenshotItemTapped(_:)")
            loadingAlert.informativeText = String(format: NSLocalizedString("Establish connection to device \"%@\"...", comment: "screenshotItemTapped(_:)"), selectedDeviceUDID)
            windowController.showSheet(loadingAlert, completionHandler: nil)
            return self.promiseProxyLookupDevice(proxy, by: selectedDeviceUDID)
        }.then { [unowned self] (device) -> Promise<Data> in
            loadingAlert.messageText = NSLocalizedString("Wait for device", comment: "screenshotItemTapped(_:)")
            loadingAlert.informativeText = String(format: NSLocalizedString("Download screenshot from device \"%@\"...", comment: "screenshotItemTapped(_:)"), device["name"]!)
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
    
    
    // MARK: - Help Actions
    
    @IBAction func showHelpPageMenuItemTapped(_ sender: NSMenuItem) {
        if let url = Bundle.main.url(forResource: "JSTColorPicker", withExtension: "html") {
            NSWorkspace.shared.open(url)
        }
    }
    
    
    // MARK: - Sparkle Hide
    @IBOutlet weak var checkForUpdatesItem: NSMenuItem!
    
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
        else if item.action == #selector(devicesTakeScreenshotMenuItemTapped(_:)) {
            #if SANDBOXED
            return applicationHasScreenshotHelper()
            #else
            return true
            #endif
        }
        return true
    }
    
}

extension AppDelegate: NSMenuDelegate {
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu == self.fileMenu {
            updateFileMenuItems()
        }
        else if menu == self.devicesMenu {
            updateDevicesMenuItems()
        }
        else if menu == self.devicesSubMenu {
            updateDevicesSubMenuItems()
        }
    }
    
}


// MARK: -

extension AppDelegate {
    
    
    // MARK: - Device List
    
    #if SANDBOXED
    fileprivate func applicationHasScreenshotHelper() -> Bool {
        let launchAgentPath = GetJSTColorPickerHelperLaunchAgentPath()
        return FileManager.default.fileExists(atPath: launchAgentPath)
    }
    #endif
    
    fileprivate func applicationSetupScreenshotHelper() {
        let enabled: Bool = UserDefaults.standard[.enableNetworkDiscovery]
        if let proxy = self.helperConnection?.remoteObjectProxyWithErrorHandler({ (error) in
            debugPrint(error)
        }) as? JSTScreenshotHelperProtocol {
            proxy.setNetworkDiscoveryEnabled(enabled)
        }
    }
    
    fileprivate func applicationResetDevicesSubMenu() {
        #if SANDBOXED
        if !applicationHasScreenshotHelper() {
            let downloadItem = NSMenuItem(title: NSLocalizedString("Download screenshot helper...", comment: "resetDevicesMenu"), action: #selector(actionRedirectToDownloadPage), keyEquivalent: "")
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
        devicesSubMenu.items = [ emptyItem ]
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
        devicesEnableNetworkDiscoveryMenuItem.state = UserDefaults.standard[.enableNetworkDiscovery] ? .on : .off
        #if SANDBOXED
        devicesTakeScreenshotMenuItem.isEnabled = applicationHasScreenshotHelper()
        #endif
    }
    
    fileprivate func updateDevicesSubMenuItems() {
        let selectedDeviceIdentifier = "\(AppDelegate.deviceIdentifierPrefix)\(self.selectedDeviceUDID ?? "")"
        for item in devicesSubMenu.items {
            guard let deviceIdentifier = item.identifier?.rawValue else { continue }
            item.isEnabled = true
            item.state = deviceIdentifier == selectedDeviceIdentifier ? .on : .off
        }
        reloadDevicesSubMenuItems()
    }
    
    fileprivate func reloadDevicesSubMenuItems() {
        guard let proxy = self.helperConnection?.remoteObjectProxyWithErrorHandler({ (error) in
            debugPrint(error)
        }) as? JSTScreenshotHelperProtocol else { return }
        
        let selectedDeviceIdentifier = "\(AppDelegate.deviceIdentifierPrefix)\(self.selectedDeviceUDID ?? "")"
        DispatchQueue.global(qos: .default).async { [weak self] in
            
            proxy.discoveredDevices { (data, error) in
                
                guard let data = data else { return }
                guard let devices = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [[String: String]] else { return }
                
                DispatchQueue.main.async { [weak self] in
                    
                    var items: [NSMenuItem] = []
                    for device in devices {
                        
                        guard let udid = device["udid"], let name = device["name"] else { continue }
                        // if self?.selectedDeviceUDID == nil { self?.selectedDeviceUDID = udid }
                        
                        let deviceIdentifier = "\(AppDelegate.deviceIdentifierPrefix)\(udid)"
                        let item = NSMenuItem(title: "\(name) (\(udid))", action: #selector(self?.actionDeviceItemTapped(_:)), keyEquivalent: "")
                        item.identifier = NSUserInterfaceItemIdentifier(rawValue: deviceIdentifier)
                        item.isEnabled = true
                        item.state = deviceIdentifier == selectedDeviceIdentifier ? .on : .off
                        items.append(item)
                        
                    }
                    
                    if items.count > 0 {
                        self?.devicesSubMenu.items = items
                    }
                    else {
                        self?.applicationResetDevicesSubMenu()
                    }
                    
                    self?.devicesSubMenu.update()
                    
                }
                
            }
            
        }
    }
    
    
    // MARK: - Device Action: Select
    
    @objc fileprivate func actionDeviceItemTapped(_ sender: NSMenuItem) {
        selectDeviceSubMenuItem(sender)
    }
    
    fileprivate func selectDeviceSubMenuItem(_ sender: NSMenuItem?) {
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
    
    @objc fileprivate func actionRedirectToDownloadPage() {
        if let url = URL(string: "https://82flex.github.io/JSTColorPicker/") {
            NSWorkspace.shared.open(url)
        }
    }
    
    
}

