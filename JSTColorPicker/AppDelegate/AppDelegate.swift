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
    
    enum InternalError: LocalizedError {
        case invalidDeviceHandler
        
        var failureReason: String? {
            switch self {
            case .invalidDeviceHandler:
                return NSLocalizedString("Invalid device handler.", comment: "InternalError")
            }
        }
    }
    
    enum XPCError: LocalizedError {
        case timeout
        
        var failureReason: String? {
            switch self {
            case .timeout:
                return NSLocalizedString("Connection timeout.", comment: "XPCError")
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
    
    enum CustomProtocolError: LocalizedError {
        case malformedResponse
        
        var failureReason: String? {
            switch self {
                case .malformedResponse:
                    return NSLocalizedString("Malformed response.", comment: "CustomProtocolError")
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
    
    
    #if APP_STORE
    @discardableResult
    internal func applicationHasScreenshotHelper() -> Bool {
        let launchAgentPath = GetJSTColorPickerHelperLaunchAgentPath()
        let isAvailable = FileManager.default.fileExists(atPath: launchAgentPath)
        if isAvailable != _isScreenshotHelperAvailable {
            _isScreenshotHelperAvailable = isAvailable
        }
        return isAvailable
    }
    #else
    @discardableResult
    internal func applicationHasScreenshotHelper() -> Bool {
        return true
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
    @IBOutlet weak var colorPanelSwitchMenuItem               : NSMenuItem!
    
    internal var firstManagedWindowController: WindowController? {
        return tabService?.firstManagedWindow?.windowController
    }
    
    internal var firstRespondingWindowController: WindowController? {
        tabService?.firstRespondingWindow?.windowController as? WindowController
    }
    
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
        
        applicationXPCSetup()
        applicationBonjourSetup()
        applicationXPCEstablish()
        applicationBonjourEstablish()
        
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
            applicationXPCSetup()
        }
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        applicationHasScreenshotHelper()
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
    internal func presentError(_ error: Error) -> Bool {
        assert(Thread.isMainThread)
        return NSApp.presentError(error)
    }
    
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
                menuItem.action == #selector(notifyDiscoverDevices(_:))
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
    
}


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

