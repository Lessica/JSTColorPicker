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
import Carbon

#if !APP_STORE
import LetsMove
#else
import SwiftyStoreKit
#endif

import AppCenter
import AppCenterAnalytics
import AppCenterCrashes

class AppDelegate: NSObject, NSApplicationDelegate {

    static var shared: AppDelegate { NSApp.delegate as! AppDelegate }

    
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
    
    var tabService: TabService?
    var helperConnection: NSXPCConnection?
    
    #if APP_STORE
    static let applicationHelperDidBecomeAvailableNotification = Notification.Name("AppDelegate.applicationHelperDidBecomeAvailableNotification")
    static let applicationHelperDidResignAvailableNotification = Notification.Name("AppDelegate.applicationHelperDidResignAvailableNotification")
    #endif
    
    #if APP_STORE
    private        var _isScreenshotHelperAvailable: Bool = false
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
    
    #if !APP_STORE
    @IBOutlet var sparkUpdater: SUUpdater!
    #else
    @IBOutlet var sparkUpdater: SUUpdater!
    #endif
    
    @IBOutlet weak var menu                                   : NSMenu!
    @IBOutlet weak var mainMenu                               : NSMenu!
    @IBOutlet weak var fileMenu                               : NSMenu!
    @IBOutlet weak var editMenu                               : NSMenu!
    @IBOutlet weak var viewMenu                               : NSMenu!
    @IBOutlet weak var sceneMenu                              : NSMenu!
    @IBOutlet weak var sceneZoomMenu                          : NSMenu!
    @IBOutlet weak var paneMenu                               : NSMenu!
    @IBOutlet weak var templateMenu                           : NSMenu!
    @IBOutlet weak var templateSubMenu                        : NSMenu!
    @IBOutlet weak var devicesMenu                            : NSMenu!
    @IBOutlet weak var devicesSubMenu                         : NSMenu!
    @IBOutlet weak var windowMenu                             : NSMenu!
    @IBOutlet weak var helpMenu                               : NSMenu!
    
    @IBOutlet weak var checkForUpdatesMenuItem                : NSMenuItem!
    @IBOutlet weak var viewSubscriptionMenuItem               : NSMenuItem!
    @IBOutlet weak var compareDocumentsMenuItem               : NSMenuItem!
    @IBOutlet weak var gridSwitchMenuItem                     : NSMenuItem!
    @IBOutlet weak var devicesEnableNetworkDiscoveryMenuItem  : NSMenuItem!
    @IBOutlet weak var devicesTakeScreenshotMenuItem          : NSMenuItem!
    
    private var firstManagedWindowController: WindowController? {
        return tabService?.firstManagedWindow?.windowController
    }
    
    private var firstRespondingWindowController: WindowController? {
        tabService?.firstRespondingWindow?.windowController as? WindowController
    }
    
    private lazy var preferencesController: PreferencesController = {
        #if APP_STORE
        let controller = PreferencesController(
            viewControllers: [
                GeneralController(),
                FolderController(),
                AdvancedController(),
                SubscriptionController()
            ],
            title: NSLocalizedString("Preferences", comment: "PreferencesController")
        )
        return controller
        #else
        let controller = PreferencesController(
            viewControllers: [
                GeneralController(),
                FolderController(),
                AdvancedController()
            ], title: NSLocalizedString("Preferences", comment: "PreferencesController")
        )
        return controller
        #endif
    }()
    
    
    // MARK: - Application Events

    func applicationWillFinishLaunching(_ notification: Notification) {
        #if !DEBUG && !APP_STORE
        PFMoveToApplicationsFolderIfNecessary()
        #endif
        #if APP_STORE
        _ = try? PurchaseManager.shared.loadLocalReceipt()
        #endif
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if objc_getClass("SUAppcast") != nil {
            viewSubscriptionMenuItem.isHidden = true
            checkForUpdatesMenuItem.isHidden = false
        } else {
            viewSubscriptionMenuItem.isHidden = false
            checkForUpdatesMenuItem.isHidden = true
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

        #if DEBUG
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationApplyPreferences(_:)),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
        applicationApplyPreferences(nil)
        #endif
        
        applicationXPCResetUI()
        applicationXPCEstablish()
        applicationXPCSetup()
        
        applicationLoadTemplatesIfNeeded()
        applicationOpenUntitledDocumentIfNeeded()
        applicationHasScreenshotHelper()
        
        #if APP_STORE
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationHelperDidBecomeAvailable(_:)),
            name: AppDelegate.applicationHelperDidBecomeAvailableNotification,
            object: self
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationHelperDidResignAvailable(_:)),
            name: AppDelegate.applicationHelperDidResignAvailableNotification,
            object: self
        )
        #endif
        
        AppCenter.start(withAppSecret: "8197ce52-8436-40f8-93b5-f9ab5e4fa331", services: [
            Analytics.self,
            Crashes.self
        ])
        
        #if APP_STORE
        if PurchaseManager.shared.getProductType() != .subscribed {
            PurchaseWindowController.shared.showWindow(self)
        }
        // see notes below for the meaning of Atomic / Non-Atomic
        SwiftyStoreKit.completeTransactions(atomically: true) { purchases in
            for purchase in purchases {
                switch purchase.transaction.transactionState {
                case .purchased, .restored:
                    if purchase.needsFinishTransaction {
                        // Deliver content from server, then:
                        SwiftyStoreKit.finishTransaction(purchase.transaction)
                    }
                    // Unlock content if possible
                    _ = try? PurchaseManager.shared.loadLocalReceipt()
                case .failed, .purchasing, .deferred:
                    break // do nothing
                @unknown default:
                    fatalError()
                }
            }
        }
        #endif
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        guard url.scheme == "jstcolorpicker" else { return }
        if url.host == "activate" {
            applicationXPCEstablish()
        }
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        applicationHasScreenshotHelper()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        self.helperConnection?.invalidate()
        self.helperConnection = nil
    }
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { return false }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { return false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return !applicationOpenUntitledDocumentIfNeeded()
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
    
    func reinitializeTabService() -> WindowController {
        //debugPrint("\(#function)")
        let windowController = WindowController.newEmptyWindow()
        tabService = TabService(initialWindowController: windowController)
        return windowController
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - Preferences Actions
    
    @objc func showPreferences(_ sender: Any?) {
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
    
    @IBAction private func showPreferencesItemTapped(_ sender: NSMenuItem) {
        showPreferences(sender)
    }
    
    
    // MARK: - Compare Actions
    
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
    
    @objc func compareDocuments(_ sender: Any?) {
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
    
    @IBAction private func compareDocumentsMenuItemTapped(_ sender: NSMenuItem) {
        compareDocuments(sender)
    }


    // MARK: - Pane Actions
    
    
    // MARK: - Color Grid Actions
    
    private var isGridVisible: Bool { GridWindowController.shared.isVisible }
    
    private func toggleGridVisibleState(_ visible: Bool, sender: Any?) {
        if visible {
            GridWindowController.shared.showWindow(sender)
        } else {
            GridWindowController.shared.close()
        }
        NSApp.invalidateRestorableState()
    }
    
    @objc func gridSwitch(_ sender: Any?) {
        if isGridVisible {
            toggleGridVisibleState(false, sender: sender)
        } else {
            toggleGridVisibleState(true, sender: sender)
        }
    }
    
    @IBAction private func gridSwitchMenuItemTapped(_ sender: NSMenuItem) {
        gridSwitch(sender)
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
    
    @IBAction private func colorPanelSwitchMenuItemTapped(_ sender: NSMenuItem) {
        if !colorPanel.isVisible {
            colorPanel.makeKeyAndOrderFront(sender)
        } else {
            colorPanel.close()
        }
    }
    
    
    // MARK: - Device Actions
    
    private var isTakingScreenshot                            : Bool = false
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
            alert.messageText = NSLocalizedString("No device selected", comment: "devicesTakeScreenshotMenuItemTapped(_:)")
            alert.informativeText = NSLocalizedString("Select an iOS device from \"Devices\" menu.", comment: "devicesTakeScreenshotMenuItemTapped(_:)")
            alert.addButton(withTitle: NSLocalizedString("OK", comment: "devicesTakeScreenshotMenuItemTapped(_:)"))
            alert.alertStyle = .informational
            windowController.showSheet(alert) { [weak self] (resp) in
                self?.isTakingScreenshot = false
            }
            return
        }
        
        let loadingAlert = NSAlert()
        loadingAlert.addButton(withTitle: NSLocalizedString("Cancel", comment: "devicesTakeScreenshotMenuItemTapped(_:)"))
        loadingAlert.alertStyle = .informational
        loadingAlert.buttons.first?.isHidden = true
        let loadingIndicator = NSProgressIndicator(frame: CGRect(x: 0, y: 0, width: 24.0, height: 24.0))
        loadingIndicator.style = .spinning
        loadingIndicator.startAnimation(nil)
        loadingAlert.accessoryView = loadingIndicator
        
        firstly { () -> Promise<[String: String]> in
            loadingAlert.messageText = NSLocalizedString("Connect to device", comment: "devicesTakeScreenshotMenuItemTapped(_:)")
            loadingAlert.informativeText = String(format: NSLocalizedString("Establish connection to device \"%@\"…", comment: "devicesTakeScreenshotMenuItemTapped(_:)"), selectedDeviceUDID)
            windowController.showSheet(loadingAlert, completionHandler: nil)
            return self.promiseProxyLookupDevice(proxy, by: selectedDeviceUDID)
        }.then { [unowned self] (device) -> Promise<Data> in
            loadingAlert.messageText = NSLocalizedString("Wait for device", comment: "devicesTakeScreenshotMenuItemTapped(_:)")
            loadingAlert.informativeText = String(format: NSLocalizedString("Download screenshot from device \"%@\"…", comment: "devicesTakeScreenshotMenuItemTapped(_:)"), device["name"]!)
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
    
    @IBAction private func devicesTakeScreenshotMenuItemTapped(_ sender: NSMenuItem) {
        takeScreenshot(sender)
    }
    
    
    // MARK: - Template Actions

    @discardableResult
    private func presentError(_ error: Error) -> Bool {
        assert(Thread.isMainThread)
        return NSApp.presentError(error)
    }
    
    @objc func showTemplates(_ sender: Any?) {
        applicationLoadTemplatesIfNeeded()
        let url = TemplateManager.templateRootURL
        guard url.isDirectory else {
            presentError(GenericError.notDirectory(url: url))
            return
        }
        NSWorkspace.shared.open(url)
    }
    
    @IBAction private func showTemplatesMenuItemTapped(_ sender: NSMenuItem) {
        showTemplates(sender)
    }
    
    @objc func showLogs(_ sender: Any?) {
        do {
            try openConsole()
        } catch {
            presentError(error)
        }
    }
    
    @IBAction private func showLogsMenuItemTapped(_ sender: NSMenuItem) {
        showLogs(sender)
    }
    
    @objc private func selectTemplateItemTapped(_ sender: NSMenuItem) {
        guard let template = sender.representedObject as? Template else { return }
        TemplateManager.shared.selectedTemplate = template
    }
    
    @objc private func reloadTemplatesItemTapped(_ sender: NSMenuItem) {
        do {
            try TemplateManager.shared.reloadTemplates()
        } catch {
            presentError(error)
        }
    }
    
    private func applicationLoadTemplatesIfNeeded() {
        let searchPaths = [
            Bundle.main.resourcePath!,
            Bundle(identifier: "com.jst.LuaC")!.resourcePath!,
            TemplateManager.templateRootURL.path
        ]
        setenv("LUA_PATH", searchPaths.reduce("") { $0 + $1 + "/?.lua;" }, 1)
        setenv("LUA_CPATH", searchPaths.reduce("") { $0 + $1 + "/?.so;" }, 1)
        if TemplateManager.shared.numberOfTemplates == 0 {
            TemplateManager.exampleTemplateURLs.forEach { (exampleTemplateURL) in
                let exampleTemplateName: String
                if exampleTemplateURL.pathExtension == "bundle" {
                    exampleTemplateName = exampleTemplateURL.deletingPathExtension().lastPathComponent
                } else {
                    exampleTemplateName = exampleTemplateURL.lastPathComponent
                }
                let newExampleTemplateURL = TemplateManager.templateRootURL.appendingPathComponent(exampleTemplateName)
                try? FileManager.default.copyItem(at: exampleTemplateURL, to: newExampleTemplateURL)
            }
            try? TemplateManager.shared.reloadTemplates()
        }
    }
    
    
    // MARK: - Help Actions
    
    @IBAction private func showHelpPageMenuItemTapped(_ sender: NSMenuItem) {
        NSWorkspace.shared.redirectToLocalHelpPage()
    }
    
    @IBAction private func actionRedirectToTermsAndPrivacyPage(_ sender: NSMenuItem) {
        NSWorkspace.shared.redirectToTermsPage()
    }
    
    @IBAction private func actionRedirectToMainPage(_ sender: NSMenuItem) {
        NSWorkspace.shared.redirectToMainPage()
    }
    
    
    // MARK: - Sparkle Actions
    
    
    // MARK: - Subscribe Actions
    
    @IBAction private func subscribeMenuItemTapped(_ sender: NSMenuItem) {
        #if APP_STORE
        PurchaseWindowController.shared.showWindow(sender)
        #endif
    }
    
    
    // MARK: - Scene Actions
    
}


// MARK: - Menu Items

extension AppDelegate: NSMenuItemValidation, NSMenuDelegate {
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let hasAttachedSheet = firstManagedWindowController?.hasAttachedSheet ?? false
        if menuItem.action == #selector(subscribeMenuItemTapped(_:)) {
            return true
        }
        else if menuItem.action == #selector(compareDocumentsMenuItemTapped(_:))
        {
            guard !hasAttachedSheet else { return false }
            if firstManagedWindowController?.shouldEndPixelMatchComparison ?? false {
                return true
            } else if let tuple = preparedPixelMatchTuple {
                return tuple.1.count > 1
                    && tuple.1.first != nil
                    && tuple.1.first?.bounds == tuple.1.last?.bounds
            } else {
                return false
            }
        }
        else if menuItem.action == #selector(devicesTakeScreenshotMenuItemTapped(_:)) ||
                menuItem.action == #selector(notifyXPCDiscoverDevices(_:))
        {
            guard !hasAttachedSheet else { return false }
            return applicationHasScreenshotHelper()
        }
        else if menuItem.action == #selector(reloadTemplatesItemTapped(_:))
        {
            guard !hasAttachedSheet else { return false }
            return !TemplateManager.shared.isLocked
        }
        else if menuItem.action == #selector(selectTemplateItemTapped(_:))
        {
            guard !hasAttachedSheet else { return false }
            guard let template = menuItem.representedObject as? Template, template.isEnabled else { return false }
            
            let enabled = Template.currentPlatformVersion.isVersion(greaterThanOrEqualTo: template.platformVersion)
            
            if enabled {
                menuItem.toolTip = """
\(template.name) (\(template.version))
by \(template.author ?? "Unknown")
------
\(template.userDescription ?? "")
"""
            }
            else {
                menuItem.toolTip = Template.Error.unsatisfiedPlatformVersion(version: template.platformVersion).failureReason
            }
            
            return enabled
        }
        
        return true
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu == self.mainMenu {
            updateMainMenuItems()
        }
        else if menu == self.fileMenu {
            updateFileMenuItems()
        }
        else if menu == self.sceneMenu {
            updateSceneMenuItems()
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
    
    private func updateMainMenuItems() {
        #if APP_STORE
        if PurchaseManager.shared.getProductType() == .subscribed {
            viewSubscriptionMenuItem.title = String(format: NSLocalizedString("View Subscription (%@)", comment: "updateMainMenuItems()"), PurchaseManager.shared.getShortReadableExpiredAt())
        } else {
            viewSubscriptionMenuItem.title = NSLocalizedString("Subscribe JSTColorPicker…", comment: "updateMainMenuItems()")
        }
        #endif
    }
    
    private func updateFileMenuItems() {
        if firstManagedWindowController?.shouldEndPixelMatchComparison ?? false {
            compareDocumentsMenuItem.title = NSLocalizedString("Exit Comparison Mode", comment: "updateMenuItems")
        }
        else if let tuple = preparedPixelMatchTuple, tuple.1.count > 1
        {
            let name1 = tuple.1
                .first!
                .imageSource
                .url
                .lastPathComponent
                .truncated(limit: 32, position: .middle)
            let name2 = tuple.1
                .last!
                .imageSource
                .url
                .lastPathComponent
                .truncated(limit: 32, position: .middle)
            compareDocumentsMenuItem.title = String(format: NSLocalizedString("Compare \"%@\" and \"%@\"", comment: "updateMenuItems"), name1, name2)
        }
        else {
            compareDocumentsMenuItem.title = NSLocalizedString("Compare Opened Documents", comment: "updateMenuItems")
        }
    }
    
    private func updateSceneMenuItems() {
        guard let toolIdent = firstRespondingWindowController?.selectedSceneToolIdentifier else { return }
        var menuItemIdent: NSUserInterfaceItemIdentifier?
        switch toolIdent {
        case .annotateItem:
            menuItemIdent = .magicCursor
        case .selectItem:
            menuItemIdent = .selectionArrow
        case .magnifyItem:
            menuItemIdent = .magnifyingGlass
        case .minifyItem:
            menuItemIdent = .minifyingGlass
        case .moveItem:
            menuItemIdent = .movingHand
        default:
            break
        }
        if let stateOnMenuItemIdent = menuItemIdent {
            sceneMenu.items
                .forEach({
                    $0.state = $0.identifier == stateOnMenuItemIdent ? .on : .off
                })
        }
    }
    
    private func updateDevicesMenuItems() {
        devicesEnableNetworkDiscoveryMenuItem.state = UserDefaults.standard[.enableNetworkDiscovery] ? .on : .off
        devicesTakeScreenshotMenuItem.isEnabled = applicationHasScreenshotHelper()
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
        let items = TemplateManager.shared.templates
            .compactMap({ [weak self] (template) -> NSMenuItem in
                itemIdx += 1
                
                var keyEqu: String?
                if itemIdx < 10 { keyEqu = String(format: "%d", itemIdx % 10) }
                
                let item = NSMenuItem(
                    title: "\(template.name) (\(template.version))",
                    action: #selector(selectTemplateItemTapped(_:)),
                    keyEquivalent: keyEqu ?? ""
                )
                
                item.target = self
                item.representedObject = template
                item.keyEquivalentModifierMask = [.control, .command]
                item.state = template.uuid == TemplateManager.shared.selectedTemplate?.uuid ? .on : .off
                
                return item
            })
        
        let separatorItem = NSMenuItem.separator()
        let reloadTemplatesItem = NSMenuItem(
            title: NSLocalizedString("Reload All Templates", comment: "updateTemplatesSubMenuItems()"),
            action: #selector(reloadTemplatesItemTapped(_:)),
            keyEquivalent: "0"
        )
        
        reloadTemplatesItem.target = self
        reloadTemplatesItem.keyEquivalentModifierMask = [.control, .command]
        reloadTemplatesItem.isEnabled = true
        reloadTemplatesItem.toolTip = NSLocalizedString("Reload template scripts from file system.", comment: "updateTemplatesSubMenuItems()")
        
        if items.count > 0 {
            templateSubMenu.items = items + [ separatorItem, reloadTemplatesItem ]
        } else {
            let emptyItem = NSMenuItem(
                title: NSLocalizedString("No template available.", comment: "updateTemplatesSubMenuItems()"),
                action: nil,
                keyEquivalent: ""
            )
            emptyItem.isEnabled = false
            templateSubMenu.items = [ emptyItem, separatorItem, reloadTemplatesItem ]
        }
    }
    
}


// MARK: - XPC Connection

extension AppDelegate {
    
    private func applicationXPCEstablish() {
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
    
    
    // MARK: - Device List
    
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
    
    private func applicationXPCSetup() {
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
    
    private func applicationXPCResetUI(with additionalItems: [NSMenuItem] = []) {
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

    @objc private func notifyXPCDiscoverDevices(_ sender: Any?) {
        guard let proxy = self.helperConnection?.remoteObjectProxyWithErrorHandler({ [weak self] (error) in
            if self?.applicationHasScreenshotHelper() ?? false {
                DispatchQueue.main.async {
                    self?.presentError(error)
                }
            }
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

    #if APP_STORE
    @objc private func actionRedirectToDownloadPage() {
        NSWorkspace.shared.redirectToHelperPage()
    }
    #endif
    
    
}


// MARK: - Debug Preferences

#if DEBUG
extension AppDelegate {
    @objc private func applicationApplyPreferences(_ notification: Notification?) {
        debugPrint("\(className):\(#function)")
    }
}
#endif


// MARK: - Restorable States

extension AppDelegate {
    
    private static let restorableGridWindowVisibleState = "GridWindowController.shared.window.isVisible"
    
    func application(_ app: NSApplication, willEncodeRestorableState coder: NSCoder) {
        coder.encode(GridWindowController.shared.isVisible, forKey: AppDelegate.restorableGridWindowVisibleState)
    }
    
    func application(_ app: NSApplication, didDecodeRestorableState coder: NSCoder) {
        toggleGridVisibleState(coder.decodeBool(forKey: AppDelegate.restorableGridWindowVisibleState), sender: app)
    }
    
}


// MARK: - Console Automation

extension AppDelegate {
    
    #if APP_STORE
    enum ScriptError: LocalizedError {
        case applicationNotFound(identifier: String)
        case cannotOpenApplicationAtURL(url: URL)
        case xpcConnectionNotEstablished

        var failureReason: String? {
            switch self {
            case let .applicationNotFound(identifier):
                return String(format: NSLocalizedString("Application \"%@\" not found.", comment: "ScriptError"), identifier)
            case let .cannotOpenApplicationAtURL(url):
                return String(format: NSLocalizedString("Cannot open application at: \"%@\".", comment: "ScriptError"), url.path)
            case .xpcConnectionNotEstablished:
                return NSLocalizedString("XPC connection to helper service is not established.", comment: "ScriptError")
            }
        }
    }
    #else
    enum ScriptError: LocalizedError {
        case unknown
        case custom(reason: String, code: Int)
        case system(dictionary: [String: Any?])
        case applicationNotFound(identifier: String)
        case cannotOpenApplicationAtURL(url: URL)
        case procNotFound(identifier: String)
        case requireUserConsentInAccessibility
        case requireUserConsentInAutomation(identifier: String)
        case notPermitted(identifier: String)

        var failureReason: String? {
            switch self {
            case .unknown:
                return NSLocalizedString("Unknown error occurred.", comment: "ScriptError")
            case let .custom(reason, code):
                return "\(reason) (\(code))."
            case let .system(dictionary):
                return "\(dictionary["NSAppleScriptErrorMessage"] as! String) (\(dictionary["NSAppleScriptErrorNumber"] as! Int))."
            case let .applicationNotFound(identifier):
                return String(format: NSLocalizedString("Application \"%@\" not found.", comment: "ScriptError"), identifier)
            case let .cannotOpenApplicationAtURL(url):
                return String(format: NSLocalizedString("Cannot open application at: \"%@\".", comment: "ScriptError"), url.path)
            case let .procNotFound(identifier):
                return String(format: NSLocalizedString("Not running application with identifier \"%@\".", comment: "ScriptError"), identifier)
            case .requireUserConsentInAccessibility:
                return NSLocalizedString("User consent required in \"Preferences > Privacy > Accessibility\".", comment: "ScriptError")
            case let .requireUserConsentInAutomation(identifier):
                return String(format: NSLocalizedString("User consent required for application with identifier \"%@\" in \"Preferences > Privacy > Automation\".", comment: "ScriptError"), identifier)
            case let .notPermitted(identifier):
                return String(format: NSLocalizedString("User did not allow usage for application with identifier \"%@\".\nPlease open \"Preferences > Privacy > Automation\" and allow access to \"Console\" and \"System Events\".", comment: "ScriptError"), identifier)
            }
        }
    }
    #endif
    
    private func promiseOpenConsole() -> Promise<URL> {
        return Promise { seal in
            let paths = [
                "/Applications/Utilities/Console.app",
                "/System/Applications/Utilities/Console.app"
            ]
            if let path = paths.first(where: { FileManager.default.fileExists(atPath: $0) }) {
                guard NSWorkspace.shared.open(URL(fileURLWithPath: path, isDirectory: true)) else {
                    seal.reject(ScriptError.cannotOpenApplicationAtURL(url: URL(fileURLWithPath: path)))
                    return
                }
                seal.fulfill(URL(fileURLWithPath: path))
                return
            }
            seal.reject(ScriptError.applicationNotFound(identifier: "com.apple.Console"))
        }
    }

    #if APP_STORE
    private func promiseConnectXPCService() -> Promise<JSTScreenshotHelperProtocol> {
        return Promise { seal in
            guard let proxy = self.helperConnection?.remoteObjectProxyWithErrorHandler({ [weak self] (error) in
                if self?.applicationHasScreenshotHelper() ?? false {
                    DispatchQueue.main.async {
                        self?.presentError(error)
                    }
                }
            }) as? JSTScreenshotHelperProtocol else {
                seal.reject(ScriptError.xpcConnectionNotEstablished)
                return
            }
            seal.fulfill(proxy)
        }
    }
    #endif

    #if APP_STORE
    private func promiseTellConsoleToStartStreaming(_ proxy: JSTScreenshotHelperProtocol) -> Promise<Bool> {
        return Promise { seal in
            proxy.tellConsoleToStartStreaming { (data, error) in
                if let error = error {
                    seal.reject(error)
                    return
                }
                seal.fulfill(true)
            }
        }
    }
    #endif

    #if APP_STORE
    @discardableResult
    private func openConsole() throws -> Bool {
        firstly {
            self.promiseOpenConsole().asVoid()
        }.then {
            self.promiseConnectXPCService()
        }.then {
            self.promiseTellConsoleToStartStreaming($0)
        }.catch {
            self.presentError($0)
        }.finally { }
        return true
    }
    #else
    @discardableResult
    private func openConsole() throws -> Bool {
        
        // open console
        try promiseOpenConsole().asVoid().wait()

        // load script
        guard let scptURL = Bundle.main.url(forResource: "open_console", withExtension: "scpt") else {
            fatalError("Internal error occurred.")
        }

        var errors: NSDictionary?
        guard let script = NSAppleScript(contentsOf: scptURL, error: &errors) else {
            throw ScriptError.system(dictionary: errors as! [String : Any?])
        }

        // setup parameters
        let message = NSAppleEventDescriptor(string: NSLocalizedString("process:JSTColorPicker", comment: "openConsole()"))
        let parameters = NSAppleEventDescriptor.list()
        parameters.insert(message, at: 1)

        // setup target
        var psn = ProcessSerialNumber(
            highLongOfPSN: 0,
            lowLongOfPSN: UInt32(kCurrentProcess)
        )
        let target = NSAppleEventDescriptor(
            descriptorType: typeProcessSerialNumber,
            bytes: &psn,
            length: MemoryLayout<ProcessSerialNumber>.size
        )

        // setup event
        let handler = NSAppleEventDescriptor(string: "open_console")
        let event = NSAppleEventDescriptor.appleEvent(
            withEventClass: AEEventClass(kASAppleScriptSuite),
            eventID: AEEventID(kASSubroutineEvent),
            targetDescriptor: target,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        
        event.setParam(handler, forKeyword: AEKeyword(keyASSubroutineName))
        event.setParam(parameters, forKeyword: AEKeyword(keyDirectObject))

        // execute
        let result = script.executeAppleEvent(event, error: &errors)
        guard result.booleanValue else {

            // ask for permission #1
            let options : NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
            let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
            guard accessibilityEnabled else {
                throw ScriptError.requireUserConsentInAccessibility
            }

            // ask for permission #2
            let askIdentifiers = [
                "com.apple.Console",
                "com.apple.systemevents",
            ]
            try askIdentifiers.forEach({ askIdentifier in
                let askTarget = NSAppleEventDescriptor(bundleIdentifier: askIdentifier)
                let askErr = AEDeterminePermissionToAutomateTarget(askTarget.aeDesc, typeWildCard, typeWildCard, true)

                switch askErr {
                case -600:
                    throw ScriptError.procNotFound(identifier: askIdentifier)
                case 0:
                    break
                case OSStatus(errAEEventWouldRequireUserConsent):
                    throw ScriptError.requireUserConsentInAutomation(identifier: askIdentifier)
                case OSStatus(errAEEventNotPermitted):
                    throw ScriptError.notPermitted(identifier: askIdentifier)
                default:
                    throw ScriptError.unknown
                }
            })

            throw ScriptError.system(dictionary: errors as! [String : Any?])
        }

        return true
    }
    #endif

}
