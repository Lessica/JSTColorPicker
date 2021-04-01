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

#if !SANDBOXED
import LetsMove
#endif

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    public static var shared: AppDelegate { NSApp.delegate as! AppDelegate }

    
    // MARK: - Structs
    
    enum XPCError: LocalizedError {
        case timeout
        
        var failureReason: String? {
            switch self {
            case .timeout:
                return NSLocalizedString("Connection timeout.", comment: "XPCError")
            }
        }
    }

    
    // MARK: - Attributes
    
    public var tabService: TabService?
    public var helperConnection: NSXPCConnection?
    
    #if !SANDBOXED
    @IBOutlet public var sparkUpdater: SUUpdater!
    #else
    @IBOutlet public var sparkUpdater: SUUpdater!
    #endif
    
    @IBOutlet weak var menu: NSMenu!
    @IBOutlet weak var mainMenu: NSMenu!
    
    private var firstManagedWindowController: WindowController? {
        return tabService?.firstManagedWindow?.windowController
    }
    
    private var firstRespondingWindowController: WindowController? {
        tabService?.firstRespondingWindow?.windowController as? WindowController
    }
    
    private lazy var preferencesController: NSWindowController = {
        let generalController = GeneralController()
        let folderController = FolderController()
        let advancedController = AdvancedController()
        let controller = PreferencesController(viewControllers: [generalController, folderController, advancedController], title: NSLocalizedString("Preferences", comment: "PreferencesController"))
        return controller
    }()
    
    
    // MARK: - Application Events

    func applicationWillFinishLaunching(_ notification: Notification) {
        #if !DEBUG && !SANDBOXED
        PFMoveToApplicationsFolderIfNecessary()
        #endif
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if objc_getClass("SUAppcast") != nil {
            checkForUpdatesItem.isHidden = false
        }
        
        var initialValues: [UserDefaults.Key: Any?] = [
            .screenshotSavingPath              : FileManager.default
                .urls(for: .picturesDirectory, in: .userDomainMask)
                .first?.appendingPathComponent("JSTColorPicker").path,
            .pixelMatchAAColor                 : NSColor.systemYellow,
            .pixelMatchDiffColor               : NSColor.systemRed,
        ]
        
        (try?
            PropertyListSerialization.propertyList(
                from: Data(contentsOf: Bundle.main.url(forResource: "InitialValues", withExtension: "plist")!),
                options: [],
                format: nil
            )
            as? [String : Any?])?.forEach({ initialValues[UserDefaults.Key(rawValue: $0.key)] = $0.value })
        
        UserDefaults.standard.register(defaults: initialValues)
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationApplyPreferences(_:)), name: UserDefaults.didChangeNotification, object: nil)
        applicationApplyPreferences(nil)
        
        applicationXPCResetUI()
        applicationXPCEstablish()
        applicationXPCSetup()
        
        applicationOpenUntitledDocumentIfNeeded()
        applicationLoadTemplatesIfNeeded()
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        guard url.scheme == "jstcolorpicker" else { return }
        if url.host == "activate" {
            applicationXPCEstablish()
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        self.helperConnection?.invalidate()
    }
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { return false }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { return false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return !applicationOpenUntitledDocumentIfNeeded()
    }
    
    private func applicationXPCEstablish() {
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
    
    @discardableResult
    private func applicationOpenUntitledDocumentIfNeeded() -> Bool {
        let availableDocuments = NSDocumentController.shared.documents.filter({ $0.windowControllers.count > 0 })
        if availableDocuments.count == 0 {
            do {
                try NSDocumentController.shared.openUntitledDocumentAndDisplay(true)
                return true
            } catch { debugPrint(error) }
        }
        return false
    }
    
    public func reinitializeTabService() -> WindowController {
        debugPrint("\(#function)")
        let windowController = WindowController.newEmptyWindow()
        tabService = TabService(initialWindowController: windowController)
        return windowController
    }
    
    
    // MARK: - Preferences Actions
    
    @IBAction func preferencesItemTapped(_ sender: Any?) {
        if let prefsWindow = preferencesController.window,
            !prefsWindow.isVisible,
            let keyScreen = tabService?.firstRespondingWindow?.screen,
            let prefsScreen = prefsWindow.screen,
            keyScreen != prefsScreen
        {
            prefsWindow.setFrameOrigin(CGPoint(
                x: keyScreen.frame.minX + ((prefsWindow.frame.minX - prefsScreen.frame.minX) / prefsScreen.frame.width * keyScreen.frame.width),
                y: keyScreen.frame.minY + ((prefsWindow.frame.minY - prefsScreen.frame.minY) / prefsScreen.frame.height * keyScreen.frame.height)
            ))
        }
        preferencesController.showWindow(sender)
    }
    
    
    // MARK: - Compare Actions
    
    @IBOutlet weak var fileMenu: NSMenu!
    @IBOutlet weak var compareMenuItem: NSMenuItem!
    
    private var preparedPixelMatchTuple: (WindowController, [PixelImage])? {
        guard let managedWindows = tabService?.managedWindows else { return nil }
        let preparedManagedWindows = managedWindows.filter({ ($0.windowController.screenshot?.state.isLoaded ?? false ) })
        guard preparedManagedWindows.count >= 2,
            let firstWindowController = managedWindows.first?.windowController,
            let firstPreparedWindowController = preparedManagedWindows.first?.windowController,
            firstWindowController === firstPreparedWindowController
            else { return nil }
        return (firstWindowController, preparedManagedWindows.compactMap({ $0.windowController.screenshot?.image }))
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


    // MARK: - Sidebar Actions

    @IBOutlet weak var paneMenu: NSMenu!

    @IBAction func resetPanes(_ sender: NSMenuItem) {
        UserDefaults.standard.removeObject(forKey: .togglePaneViewInformation)
        UserDefaults.standard.removeObject(forKey: .togglePaneViewInspector)
        UserDefaults.standard.removeObject(forKey: .togglePaneViewPreview)
        UserDefaults.standard.removeObject(forKey: .togglePaneViewTagList)
        UserDefaults.standard[.resetPaneView] = true
    }

    @IBAction func togglePane(_ sender: NSMenuItem) {
        var defaultKey: UserDefaults.Key?
        if sender.identifier == .togglePaneViewInformation {
            defaultKey = .togglePaneViewInformation
        }
        else if sender.identifier == .togglePaneViewInspector {
            defaultKey = .togglePaneViewInspector
        }
        else if sender.identifier == .togglePaneViewPreview {
            defaultKey = .togglePaneViewPreview
        }
        else if sender.identifier == .togglePaneViewTagList {
            defaultKey = .togglePaneViewTagList
        }
        if let key = defaultKey {
            let val: Bool = UserDefaults.standard[key]
            UserDefaults.standard[key] = !val
            sender.state = !val ? .on : .off
        }
    }
    
    
    // MARK: - Color Grid Actions
    
    @IBOutlet weak var gridSwitchMenuItem: NSMenuItem!
    
    private var isGridVisible: Bool { GridWindowController.shared.isVisible }
    
    private func toggleGridVisibleState(_ visible: Bool, sender: Any?) {
        if visible {
            GridWindowController.shared.showWindow(sender)
        } else {
            GridWindowController.shared.close()
        }
        NSApp.invalidateRestorableState()
    }
    
    @IBAction func gridSwitchMenuItemTapped(_ sender: Any?) {
        if isGridVisible {
            toggleGridVisibleState(false, sender: sender)
        } else {
            toggleGridVisibleState(true, sender: sender)
        }
    }
    
    
    // MARK: - Color Panel Actions
    
    private var colorPanel: NSColorPanel {
        let panel = NSColorPanel.shared
        panel.showsAlpha = true
        panel.isContinuous = true
        panel.touchBar = nil
        return panel
    }
    
    @IBOutlet weak var colorPanelSwitchMenuItem: NSMenuItem!
    
    @IBAction func colorPanelSwitchMenuItemTapped(_ sender: Any) {
        if !colorPanel.isVisible {
            colorPanel.makeKeyAndOrderFront(sender)
        } else {
            colorPanel.close()
        }
    }
    
    
    // MARK: - Device Actions
    
    private var isTakingScreenshot                            : Bool = false
    @IBOutlet weak var devicesEnableNetworkDiscoveryMenuItem  : NSMenuItem!
    @IBOutlet weak var devicesTakeScreenshotMenuItem          : NSMenuItem!
    @IBOutlet weak var devicesMenu                            : NSMenu!
    @IBOutlet weak var devicesSubMenu                         : NSMenu!
    private static let deviceIdentifierPrefix                 : String = "device-"
    private var selectedDeviceUDID                            : String?
    {
        get { UserDefaults.standard[.lastSelectedDeviceUDID]            }
        set { UserDefaults.standard[.lastSelectedDeviceUDID] = newValue }
    }
    private static var screenshotDateFormatter                : DateFormatter =
    {
        let formatter = DateFormatter.init()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter
    }()
    
    @IBAction func enableNetworkDiscoveryMenuItemTapped(_ sender: NSMenuItem) {
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
    
    @IBAction func devicesTakeScreenshotMenuItemTapped(_ sender: Any?) {
        
        guard !self.isTakingScreenshot else { return }
        self.isTakingScreenshot = true
        
        guard let picturesDirectoryPath: String = UserDefaults.standard[.screenshotSavingPath] else { return }
        guard let windowController = firstRespondingWindowController else { return }
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
    
    
    // MARK: - Template Actions
    
    @IBOutlet weak var templateMenu: NSMenu!
    @IBOutlet weak var templateSubMenu: NSMenu!
    
    @IBAction func showTemplatesMenuItemTapped(_ sender: NSMenuItem) {
        applicationLoadTemplatesIfNeeded()
        NSWorkspace.shared.open(ExportManager.templateRootURL)
    }
    
    @IBAction func showLogsMenuItemTapped(_ sender: NSMenuItem) {
        let paths = [
            "/Applications/Utilities/Console.app",
            "/System/Applications/Utilities/Console.app"
        ]
        if let path = paths.first(where: { FileManager.default.fileExists(atPath: $0) }) {
            NSWorkspace.shared.open(URL(fileURLWithPath: path, isDirectory: true))
        }
    }
    
    @objc private func selectTemplateItemTapped(_ sender: NSMenuItem) {
        guard let identifier = sender.identifier?.rawValue else { return }
        guard identifier.lengthOfBytes(using: .utf8) > 0 else { return }
        let beginIdx = identifier.index(identifier.startIndex, offsetBy: ExportManager.templateIdentifierPrefix.lengthOfBytes(using: .utf8))
        let udidString = String(identifier[beginIdx...])
        ExportManager.selectedTemplateUUID = UUID(uuidString: udidString)
    }
    
    @objc private func reloadTemplatesItemTapped(_ sender: NSMenuItem) {
        do {
            try ExportManager.reloadTemplates()
        } catch {
            firstRespondingWindowController?.presentError(error)
        }
    }
    
    private func applicationLoadTemplatesIfNeeded() {
        let searchPaths = [
            Bundle.main.resourcePath!,
            Bundle(identifier: "com.jst.LuaC")!.resourcePath!,
            ExportManager.templateRootURL.path
        ]
        setenv("LUA_PATH", searchPaths.reduce("") { $0 + $1 + "/?.lua;" }, 1)
        setenv("LUA_CPATH", searchPaths.reduce("") { $0 + $1 + "/?.so;" }, 1)
        if ExportManager.templates.count == 0 {
            ExportManager.exampleTemplateURLs.forEach { (exampleTemplateURL) in
                let exampleTemplateName = exampleTemplateURL.lastPathComponent
                let newExampleTemplateURL = ExportManager.templateRootURL.appendingPathComponent(exampleTemplateName)
                try? FileManager.default.copyItem(at: exampleTemplateURL, to: newExampleTemplateURL)
            }
            try? ExportManager.reloadTemplates()
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


// MARK: -

extension AppDelegate: NSMenuItemValidation, NSMenuDelegate {
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let hasAttachedSheet = firstManagedWindowController?.hasAttachedSheet ?? false
        if menuItem.action == #selector(togglePane(_:)) ||
           menuItem.action == #selector(resetPanes(_:))
        {
            guard !hasAttachedSheet else { return false }
            return true
        }
        else if menuItem.action == #selector(compareMenuItemTapped(_:))
        {
            guard !hasAttachedSheet else { return false }
            if firstManagedWindowController?.shouldEndPixelMatchComparison ?? false {
                return true
            } else if preparedPixelMatchTuple != nil {
                return true
            } else {
                return false
            }
        }
        else if menuItem.action == #selector(devicesTakeScreenshotMenuItemTapped(_:)) ||
                menuItem.action == #selector(notifyXPCDiscoverDevices(_:))
        {
            guard !hasAttachedSheet else { return false }
            #if SANDBOXED
            return applicationHasScreenshotHelper()
            #else
            return true
            #endif
        }
        else if menuItem.action == #selector(reloadTemplatesItemTapped(_:)) ||
                menuItem.action == #selector(selectTemplateItemTapped(_:))
        {
            guard !hasAttachedSheet else { return false }
        }
        return true
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu == self.fileMenu {
            updateFileMenuItems()
        }
        else if menu == self.paneMenu {
            updatePaneMenuItems()
        }
        else if menu == self.devicesMenu {
            updateDevicesMenuItems()
        }
        else if menu == self.devicesSubMenu {
            updateDevicesSubMenuItems()
        }
        else if menu == self.templateSubMenu {
            updateTemplatesSubMenuItems()
        }
    }
    
    private func updateFileMenuItems() {
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

    private func updatePaneMenuItems() {
        paneMenu.items.forEach { (menuItem) in
            if menuItem.identifier == .togglePaneViewInformation {
                menuItem.state = UserDefaults.standard[.togglePaneViewInformation] ? .on : .off
            }
            else if menuItem.identifier == .togglePaneViewInspector {
                menuItem.state = UserDefaults.standard[.togglePaneViewInspector] ? .on : .off
            }
            else if menuItem.identifier == .togglePaneViewPreview {
                menuItem.state = UserDefaults.standard[.togglePaneViewPreview] ? .on : .off
            }
            else if menuItem.identifier == .togglePaneViewTagList {
                menuItem.state = UserDefaults.standard[.togglePaneViewTagList] ? .on : .off
            }
        }
    }
    
    private func updateDevicesMenuItems() {
        devicesEnableNetworkDiscoveryMenuItem.state = UserDefaults.standard[.enableNetworkDiscovery] ? .on : .off
        #if SANDBOXED
        devicesTakeScreenshotMenuItem.isEnabled = applicationHasScreenshotHelper()
        #endif
    }
    
    private func updateDevicesSubMenuItems() {
        let selectedDeviceIdentifier = "\(AppDelegate.deviceIdentifierPrefix)\(self.selectedDeviceUDID ?? "")"
        for item in devicesSubMenu.items {
            guard let deviceIdentifier = item.identifier?.rawValue else { continue }
            item.isEnabled = true
            item.state = deviceIdentifier == selectedDeviceIdentifier ? .on : .off
        }
        reloadDevicesSubMenuItems()
    }
    
    private func reloadDevicesSubMenuItems() {
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
    
    private func updateTemplatesSubMenuItems() {
        var itemIdx: Int = 0
        let items = ExportManager.templates
            .compactMap({ [weak self] (template) -> NSMenuItem in
                
                itemIdx += 1
                var keyEqu = ""
                if itemIdx < 10 {
                    keyEqu = String(format: "%d", itemIdx % 10)
                }
                
                let item = NSMenuItem(title: "\(template.name) (\(template.version))", action: #selector(selectTemplateItemTapped(_:)), keyEquivalent: keyEqu)
                item.target = self
                item.identifier = NSUserInterfaceItemIdentifier(rawValue: "\(ExportManager.templateIdentifierPrefix)\(template.uuid.uuidString)")
                item.keyEquivalentModifierMask = [.control, .command]
                
                let enabled = Template.currentPlatformVersion.isVersion(greaterThanOrEqualTo: template.platformVersion)
                item.isEnabled = enabled
                item.state = template.uuid.uuidString == ExportManager.selectedTemplate?.uuid.uuidString ? .on : .off
                
                if enabled {
                    item.toolTip = """
\(template.name) (\(template.version))
by \(template.author ?? "Unknown")
------
\(template.description ?? "")
"""
                }
                else {
                    item.toolTip = Template.Error.unsatisfiedPlatformVersion(version: template.platformVersion).failureReason
                }
                
                return item
            })
            .sorted(by: { $0.title.compare($1.title) == .orderedAscending })
        
        let separatorItem = NSMenuItem.separator()
        let reloadTemplatesItem = NSMenuItem(title: NSLocalizedString("Reload All Templates", comment: "updateTemplatesSubMenuItems()"), action: #selector(reloadTemplatesItemTapped(_:)), keyEquivalent: "0")
        reloadTemplatesItem.toolTip = NSLocalizedString("Reload template scripts from file system.", comment: "updateTemplatesSubMenuItems()")
        
        reloadTemplatesItem.keyEquivalentModifierMask = [.control, .command]
        templateSubMenu.items = items + [ separatorItem, reloadTemplatesItem ]
    }
    
}


// MARK: -

extension AppDelegate {
    
    
    // MARK: - Device List
    
    #if SANDBOXED
    public func applicationHasScreenshotHelper() -> Bool {
        let launchAgentPath = GetJSTColorPickerHelperLaunchAgentPath()
        return FileManager.default.fileExists(atPath: launchAgentPath)
    }
    #endif
    
    private func applicationXPCSetup() {
        let enabled: Bool = UserDefaults.standard[.enableNetworkDiscovery]
        if let proxy = self.helperConnection?.remoteObjectProxyWithErrorHandler({ (error) in
            debugPrint(error)
        }) as? JSTScreenshotHelperProtocol {
            proxy.setNetworkDiscoveryEnabled(enabled)
            proxy.discoverDevices()
        }
    }
    
    private func applicationXPCResetUI(with additionalItems: [NSMenuItem] = []) {
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
        devicesSubMenu.items = [ emptyItem ] + additionalItems
    }

    @objc private func notifyXPCDiscoverDevices(_ sender: Any?) {
        guard let proxy = self.helperConnection?.remoteObjectProxyWithErrorHandler({ (error) in
            debugPrint(error)
        }) as? JSTScreenshotHelperProtocol else { return }
        proxy.discoverDevices()
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
    
    @objc private func actionRedirectToDownloadPage() {
        if let url = URL(string: "https://82flex.github.io/JSTColorPicker/") {
            NSWorkspace.shared.open(url)
        }
    }
    
    
}


// MARK: -

extension AppDelegate {
    
    @objc private func applicationApplyPreferences(_ notification: Notification?) {
        debugPrint("\(className):\(#function)")
    }
    
}


// MARK: -

extension AppDelegate {
    
    private static let restorableGridWindowVisibleState = "GridWindowController.shared.window.isVisible"
    
    func application(_ app: NSApplication, willEncodeRestorableState coder: NSCoder) {
        coder.encode(GridWindowController.shared.isVisible, forKey: AppDelegate.restorableGridWindowVisibleState)
    }
    
    func application(_ app: NSApplication, didDecodeRestorableState coder: NSCoder) {
        toggleGridVisibleState(coder.decodeBool(forKey: AppDelegate.restorableGridWindowVisibleState), sender: app)
    }
    
}

