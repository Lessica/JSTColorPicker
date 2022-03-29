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
import SwiftBonjour

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
        case interrupted
        case invalidated
        case malformedResponse
        case invalidDeviceHandler(handler: String)
        
        var failureReason: String? {
            switch self {
                case .timeout:
                    return NSLocalizedString("Connection timeout.", comment: "XPCError")
                case .interrupted:
                    return NSLocalizedString("Connection interrupted.", comment: "XPCError")
                case .invalidated:
                    return NSLocalizedString("Connection invalidated.", comment: "XPCError")
                case .malformedResponse:
                    return NSLocalizedString("Malformed response.", comment: "XPCError")
                case .invalidDeviceHandler(let handler):
                    return String(format: NSLocalizedString("Invalid device handler: %@.", comment: "XPCError"), handler)
            }
        }
    }
    
    enum NetworkError: LocalizedError {
        case cannotResolveName(name: String)
        
        var failureReason: String? {
            switch self {
                case let .cannotResolveName(name):
                    return String(format: NSLocalizedString("Cannot resolve name: %@", comment: "NetworkError"), name)
            }
        }
    }

    
    // MARK: - Attributes
    
    var tabService                         : TabService?
    var helperConnection                   : NSXPCConnection?
    var helperBonjourBrowser               : BonjourBrowser?
    var helperBonjourDevices               : Set<BonjourDevice> = Set<BonjourDevice>()
    var helperSession                      = URLSession(configuration: .ephemeral)
    private let observableKeys             : [UserDefaults.Key] = [.enableNetworkDiscovery]
    private var observables                : [Observable]?
    internal var isNetworkDiscoveryEnabled : Bool = false
    internal var isTakingScreenshot        : Bool = false
    
    enum HelperState {
        case missing
        case outdated
        case latest
        
        var exists: Bool { self != .missing }
    }
    
    #if APP_STORE
    var screenshotHelperState: HelperState = .missing
    {
        didSet {
            if screenshotHelperState.exists {
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
    

    internal var helperConnectionInvalidatedManually = false
    #if APP_STORE
    @discardableResult
    func applicationCheckScreenshotHelper() -> HelperState {
        let launchAgentURL = URL(fileURLWithPath: GetJSTColorPickerHelperLaunchAgentPath())
        let doesLaunchAgentExist = FileManager.default.fileExists(atPath: launchAgentURL.path)
        if doesLaunchAgentExist && screenshotHelperState == .missing {
            screenshotHelperState = .latest
        }
        return screenshotHelperState
    }
    private var helperConnectionFailureErrorPresented = false
    func presentHelperConnectionFailureError(_ error: Error) {
        if (!helperConnectionFailureErrorPresented) {
            // present only once
            screenshotHelperState = .outdated
            helperConnectionFailureErrorPresented = true
            NSAlert.action(
                text: .init(
                    message: NSLocalizedString("Helper Connection Failure", comment: "presentHelperConnectionFailureError(_:)"),
                    information: String(format: NSLocalizedString("%@\nThis is most likely due to an outdated or incorrect helper installation, and we strongly advise that you download and install helper application again.", comment: "presentHelperConnectionFailureError(_:)"), error.localizedDescription)
                ),
                button: .init(title: NSLocalizedString("Redirect to download page", comment: "presentHelperConnectionFailureError(_:)"))
            ).then { [unowned self] () -> Promise<Void> in
                self.actionRedirectToDownloadPage()
                return self.promiseVoid
            }.catch { _ in }
        }
    }
    #else
    @discardableResult
    func applicationCheckScreenshotHelper() -> HelperState {
        return .latest
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
    @IBOutlet weak var viewPanelMenu                          : NSMenu!
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
    @IBOutlet weak var devicesEnableNetworkDiscoveryMenuItem  : NSMenuItem!
    @IBOutlet weak var devicesTakeScreenshotMenuItem          : NSMenuItem!
    
    internal var firstRespondingWindowController: WindowController? {
        tabService?.firstRespondingWindow?.windowController as? WindowController
    }
    
    private var initialPreferencesControllerViewIdentifier: String?
    internal lazy var preferencesController: PreferencesController = {
        #if APP_STORE
        let controller = PreferencesController(
            viewControllers: [
                GeneralController(),
                KeyBindingsController(),
                FolderController(),
                AdvancedController(),
                SubscriptionController()
            ],
            title: NSLocalizedString("Preferences", comment: "PreferencesController")
        )
        if let initialPreferencesControllerViewIdentifier = initialPreferencesControllerViewIdentifier
        {
            controller.select(withIdentifier: initialPreferencesControllerViewIdentifier)
        }
        return controller
        #else
        let controller = PreferencesController(
            viewControllers: [
                GeneralController(),
                KeyBindingsController(),
                FolderController(),
                AdvancedController()
            ], title: NSLocalizedString("Preferences", comment: "PreferencesController")
        )
        if let initialPreferencesControllerViewIdentifier = initialPreferencesControllerViewIdentifier
        {
            controller.select(withIdentifier: initialPreferencesControllerViewIdentifier)
        }
        return controller
        #endif
    }()
    
    @objc private func registerInitialValuesNotification(_ notification: NSNotification? = nil)
    {
        // reset key bindings
        MenuKeyBindingManager.shared.applyKeyBindingsToMainMenu()
        
        // read notification user info
        var initialURL = notification?.userInfo?["url"] as? URL
        
        // read local overrides
        if initialURL == nil {
            let localOverrideURL = PreferencesController.initialValuesURL
            if (try? localOverrideURL.checkResourceIsReachable()) ?? false {
                initialURL = localOverrideURL
            }
        }
        
        // read bundled initial values
        if initialURL == nil {
            initialURL = Bundle.main.url(forResource: "InitialValues", withExtension: "plist")
        }
        
        guard let initialURL = initialURL else {
            return
        }
        
        var initialValues: [UserDefaults.Key: Any?] = [
            .screenshotSavingPath              : FileManager.default
                .urls(for: .picturesDirectory, in: .userDomainMask)
                .first?.appendingPathComponent("JSTColorPicker").path,
            .pixelMatchAAColor                 : NSColor.systemYellow,
            .pixelMatchDiffColor               : NSColor.systemRed,
            .colorGridColorAnnotatorColor      : NSColor.systemRed,
            .colorGridAreaAnnotatorColor       : NSColor.systemBlue,
        ]
        
        guard let initialData = try? Data(contentsOf: initialURL) else { return }
        guard let initialObject = try?
            PropertyListSerialization.propertyList(
                from: initialData,
                options: [],
                format: nil
            )
            as? [String: Any?] else { return }
        
        initialObject.forEach({
            initialValues[UserDefaults.Key(rawValue: $0.key)] = $0.value
        })
        
        UserDefaults.standard.register(defaults: initialValues)
    }
    
    @objc private func prepareInitialPreferencesControllerViewIdentifierNotification(_ notification: NSNotification? = nil)
    {
        initialPreferencesControllerViewIdentifier = notification?.userInfo?["viewIdentifier"] as? String
        showPreferences(self)
    }
    
    
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
        
        registerInitialValuesNotification()
        prepareDefaults()
        observables = UserDefaults.standard.observe(keys: observableKeys, callback: { [weak self] in self?.applyDefaults($0, $1, $2) })
        
        #if DEBUG
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationApplyPreferences(_:)),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
        applicationApplyPreferences(nil)
        #endif
        
        applicationResetDeviceUI()
        
        applicationXPCSetup(deactivate: false)
        applicationBonjourSetup(deactivate: false)
        
        applicationXPCReloadDevices()
        applicationBonjourReloadDevices()
        
        applicationLoadTemplatesIfNeeded()
        applicationOpenUntitledDocumentIfNeeded()
        applicationCheckScreenshotHelper()
        
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationHelperConnectionFailure(_:)),
            name: AppDelegate.applicationHelperConnectionDidInvalidatedNotification,
            object: self
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationHelperConnectionFailure(_:)),
            name: AppDelegate.applicationHelperConnectionDidInterruptedNotification,
            object: self
        )
        #endif
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(registerInitialValuesNotification(_:)),
            name: PreferencesController.registerInitialValuesNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(prepareInitialPreferencesControllerViewIdentifierNotification(_:)),
            name: PreferencesController.makeKeyAndOrderFrontNotification,
            object: nil
        )
        
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
            applicationXPCSetup(deactivate: true)
        }
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        applicationCheckScreenshotHelper()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        applicationXPCDeactivate()
        applicationBonjourDeactivate()
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
    
    @discardableResult
    func presentError(_ error: Error) -> Bool {
        assert(Thread.isMainThread)
        return NSApp.presentError(error)
    }
    
}


// MARK: - Menu Items

extension AppDelegate: NSMenuItemValidation, NSMenuDelegate {
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let hasAttachedSheet = firstRespondingWindowController?.hasAttachedSheet ?? false
        if menuItem.action == #selector(subscribeMenuItemTapped(_:)) {
            return true
        }
        else if menuItem.action == #selector(compareDocumentsMenuItemTapped(_:))
        {
            guard !hasAttachedSheet else { return false }
            if firstRespondingWindowController?.shouldEndPixelMatchComparison ?? false {
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
                menuItem.action == #selector(notifyDiscoverDevices(_:))
        {
            guard !hasAttachedSheet else { return false }
            return applicationCheckScreenshotHelper().exists
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
            updateMainMenuItems(menu)
        }
        else if menu == self.fileMenu {
            updateFileMenuItems(menu)
        }
        else if menu == self.viewPanelMenu {
            updateViewPanelMenuItems(menu)
        }
        else if menu == self.sceneMenu {
            updateSceneMenuItems(menu)
        }
        else if menu == self.devicesMenu {
            updateDevicesMenuItems(menu)
        }
        else if menu == self.devicesSubMenu {
            updateDevicesSubMenuItems(menu)
        }
        else if menu == self.templateSubMenu {
            updateTemplatesSubMenuItems(menu)
        }
    }
    
    private func updateMainMenuItems(_ menu: NSMenu) {
        #if APP_STORE
        if PurchaseManager.shared.getProductType() == .subscribed {
            viewSubscriptionMenuItem.title = String(format: NSLocalizedString("View Subscription (%@)", comment: "updateMainMenuItems()"), PurchaseManager.shared.getShortReadableExpiredAt())
        } else {
            viewSubscriptionMenuItem.title = NSLocalizedString("Subscribe JSTColorPicker…", comment: "updateMainMenuItems()")
        }
        #endif
    }
    
    private func updateFileMenuItems(_ menu: NSMenu) {
        if firstRespondingWindowController?.shouldEndPixelMatchComparison ?? false {
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
    
    private func updateViewPanelMenuItems(_ menu: NSMenu) {
        for menuItem in menu.items {
            guard let menuIdentifier = menuItem.identifier else { continue }
            switch menuIdentifier {
                case .panelBrowser:
                    menuItem.state = isBrowserVisible ? .on : .off
                case .panelColorPanel:
                    menuItem.state = isColorPanelVisible ? .on : .off
                case .panelColorGrid:
                    menuItem.state = isColorGridVisible ? .on : .off
                default:
                    break
            }
        }
    }
    
    private func updateSceneMenuItems(_ menu: NSMenu) {
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
    
}


// MARK: - Restorable States

extension AppDelegate {
    
    private static let restorableBrowserWindowVisibleState = "restoration:browserWindowVisibleState"
    private static let restorableColorGridWindowVisibleState = "restoration:colorGridWindowVisibleState"
    
    func application(_ app: NSApplication, willEncodeRestorableState coder: NSCoder) {
        coder.encode(isBrowserVisible, forKey: AppDelegate.restorableBrowserWindowVisibleState)
        coder.encode(isColorGridVisible, forKey: AppDelegate.restorableColorGridWindowVisibleState)
    }
    
    func application(_ app: NSApplication, didDecodeRestorableState coder: NSCoder) {
        toggleBrowserVisibleState(coder.decodeBool(forKey: AppDelegate.restorableBrowserWindowVisibleState), sender: app)
        toggleColorGridVisibleState(coder.decodeBool(forKey: AppDelegate.restorableColorGridWindowVisibleState), sender: app)
    }
    
}


// MARK: - XPC Promises

extension AppDelegate {
    
    func promiseXPCProxy() -> Promise<JSTScreenshotHelperProtocol> {
        return Promise<JSTScreenshotHelperProtocol> { [weak self] seal in
            if let proxy = self?.helperConnection?.remoteObjectProxyWithErrorHandler({ error in
                seal.reject(error)
            }) as? JSTScreenshotHelperProtocol
            {
                seal.fulfill(proxy)
            } else {
                seal.reject(XPCError.interrupted)
            }
        }
    }
    
    func promiseXPCServiceInfo(_ proxy: JSTScreenshotHelperProtocol) -> Promise<Data> {
        return Promise<Data> { seal in
            DispatchQueue.global(qos: .userInitiated).async {
                proxy.getHelperInfoDictionary { data, err in
                    if let err = err {
                        seal.reject(err)
                    } else if let data = data {
                        seal.fulfill(data)
                    }
                }
            }
        }
    }
    
    func promiseXPCServiceVersion(_ serviceInfo: [String: Any]) -> Promise<String> {
        return Promise<String> { seal in
            if let versionString = serviceInfo[kCFBundleVersionKey as String] as? String {
                seal.fulfill(versionString)
            } else {
                seal.reject(XPCError.malformedResponse)
            }
        }
    }
    
    func promiseXPCParseResponse<T>(_ data: Data) -> Promise<T> {
        return Promise<T> { seal in
            guard let respObj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? T
            else {
                seal.reject(XPCError.malformedResponse)
                return
            }
            seal.fulfill(respObj)
        }
    }
    
    var promiseVoid: Promise<Void> { Promise<Void>() }
    
}

