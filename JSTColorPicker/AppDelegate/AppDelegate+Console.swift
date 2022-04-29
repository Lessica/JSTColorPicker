//
//  AppDelegate+Console.swift
//  JSTColorPicker
//
//  Created by Darwin on 6/8/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Carbon
import Cocoa
import PromiseKit


// MARK: - Console Automation

extension AppDelegate {
    
    #if APP_STORE
    enum ScriptError: CustomNSError, LocalizedError {
        case applicationNotFound(identifier: String)
        case cannotOpenApplicationAtURL(url: URL)
        
        var errorCode: Int {
            switch self {
                case .applicationNotFound(_):
                    return 604
                case .cannotOpenApplicationAtURL(_):
                    return 605
            }
        }
        
        var failureReason: String? {
            switch self {
                case let .applicationNotFound(identifier):
                    return String(format: NSLocalizedString("Application “%@” not found.", comment: "ScriptError"), identifier)
                case let .cannotOpenApplicationAtURL(url):
                    return String(format: NSLocalizedString("Cannot open application at: “%@”.", comment: "ScriptError"), url.path)
            }
        }
    }
    #else
    enum ScriptError: CustomNSError, LocalizedError {
        case unknown
        case custom(reason: String, code: Int)
        case system(dictionary: [String: Any?])
        case applicationNotFound(identifier: String)
        case cannotOpenApplicationAtURL(url: URL)
        case procNotFound(identifier: String)
        case requireUserConsentInAccessibility
        case requireUserConsentInAutomation(identifier: String)
        case notPermitted(identifier: String)
        
        var errorCode: Int {
            switch self {
                case .unknown:
                    return 601
                case .custom(_, _):
                    return 602
                case .system(_):
                    return 603
                case .applicationNotFound(_):
                    return 604
                case .cannotOpenApplicationAtURL(_):
                    return 605
                case .procNotFound(_):
                    return 606
                case .requireUserConsentInAccessibility:
                    return 607
                case .requireUserConsentInAutomation(_):
                    return 608
                case .notPermitted(_):
                    return 609
            }
        }
        
        var failureReason: String? {
            switch self {
                case .unknown:
                    return NSLocalizedString("Unknown error occurred.", comment: "ScriptError")
                case let .custom(reason, code):
                    return "\(reason) (\(code))."
                case let .system(dictionary):
                    return "\(dictionary["NSAppleScriptErrorMessage"] as! String) (\(dictionary["NSAppleScriptErrorNumber"] as! Int))."
                case let .applicationNotFound(identifier):
                    return String(format: NSLocalizedString("Application “%@” not found.", comment: "ScriptError"), identifier)
                case let .cannotOpenApplicationAtURL(url):
                    return String(format: NSLocalizedString("Cannot open application at: “%@”.", comment: "ScriptError"), url.path)
                case let .procNotFound(identifier):
                    return String(format: NSLocalizedString("Not running application with identifier “%@”.", comment: "ScriptError"), identifier)
                case .requireUserConsentInAccessibility:
                    return NSLocalizedString("User consent required in “Preferences > Privacy > Accessibility”.", comment: "ScriptError")
                case let .requireUserConsentInAutomation(identifier):
                    return String(format: NSLocalizedString("User consent required for application with identifier “%@” in “Preferences > Privacy > Automation”.", comment: "ScriptError"), identifier)
                case let .notPermitted(identifier):
                    return String(format: NSLocalizedString("User did not allow usage for application with identifier “%@”.\nPlease open “Preferences > Privacy > Automation” and allow access to “Console” and “System Events”.", comment: "ScriptError"), identifier)
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
    internal func openConsole() throws -> Bool {
        firstly { [unowned self] in
            self.promiseOpenConsole().asVoid()
        }.then { [unowned self] in
            self.promiseXPCProxy()
        }.then { [unowned self] in
            self.promiseTellConsoleToStartStreaming($0)
        }.catch { [unowned self] err in
            if self.applicationCheckScreenshotHelper().exists {
                DispatchQueue.main.async {
                    self.presentError(err)
                }
            }
        }.finally { }
        return true
    }
    #else
    @discardableResult
    internal func openConsole() throws -> Bool {
        
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

