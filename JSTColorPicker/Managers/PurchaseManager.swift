//
//  PurchaseManager.swift
//  JSTColorPicker
//
//  Created by Rachel on 4/23/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Foundation
import Combine

#if APP_STORE
import SwiftyStoreKit
import TPInAppReceipt
#else
import Paddle
#endif

@objc final class PurchaseManager: NSObject {
    
    static let productTypeDidChangeNotification    = Notification.Name("PurchaseManager.productTypeDidChangeNotification")
    static let productDeactivatedNotification      = Notification.Name("PurchaseManager.productDeactivatedNotification")
    static let productForceDeactivateNotification  = Notification.Name("PurchaseManager.productForceDeactivateNotification")
    
    enum Error: CustomNSError, LocalizedError {
        case invalidReceipt
        case invalidPurchase
        case notPurchased
        case expired(at: Date)
        
        var errorCode: Int {
            switch self {
                case .invalidReceipt:
                    return 1401
                case .invalidPurchase:
                    return 1402
                case .notPurchased:
                    return 1403
                case .expired(_):
                    return 1404
            }
        }
        
        var failureReason: String? {
            switch self {
                case .invalidReceipt:
                    return NSLocalizedString("Invalid receipt.", comment: "PurchaseManager.Error")
                case .invalidPurchase:
                    return NSLocalizedString("Invalid purchase.", comment: "PurchaseManager.Error")
                case .notPurchased:
                    return NSLocalizedString("Not purchased.", comment: "PurchaseManager.Error")
                case let .expired(at):
                    return String(
                        format: NSLocalizedString("Your previous subscription has expired since %@. Please renew your subscription.", comment: "PurchaseManager.Error"),
                        PurchaseManager.mediumExpiryDateFormatter.string(from: at)
                    )
            }
        }
    }
    
    enum ProductType: Int {
        case uninitialized
        case demoVersion
        case subscribed
        case expired
        
        var localizedString: String {
            switch self {
            case .uninitialized:
                return NSLocalizedString("Uninitialized", comment: "PurchaseManager.ProductType")
            case .demoVersion:
                return NSLocalizedString("Demo Version", comment: "PurchaseManager.ProductType")
            case .subscribed:
                return NSLocalizedString("Subscribed", comment: "PurchaseManager.ProductType")
            case .expired:
                return NSLocalizedString("Expired", comment: "PurchaseManager.ProductType")
            }
        }
    }
    
    static var shared                          = PurchaseManager()
    
#if APP_STORE
    static let channelName                     = "App Store"
    static let sharedProductID                 = "com.jst.JSTColorPicker.Subscription.Yearly"
    static let sharedSecret                    = "53cbec8e68f445c596ce0c3e059a1f06"
#else
    static let channelName                     = "Paddle.com"
    #if DEBUG
        
    // Sandbox Vendor
    private static let sharedPaddleVendorID    = "5790"
    private static let sharedPaddleProductID   = "27361"
    private static let sharedPaddleAPIKey      = "b7f5f632ecdef9b9524a5f2fdd63990d"
    private static var sharedProductConfig     : PADProductConfiguration = {
        let productConfig = PADProductConfiguration()
        productConfig.productName = "JSTColorPicker (1 year)"
        productConfig.vendorName = "82Flex"
        productConfig.currency = "USD"
        productConfig.price = 14.99
        productConfig.trialType = .none
        return productConfig
    }()
        
    #else
        
    // Sandbox Vendor
    private static let sharedPaddleVendorID    = "145985"
    private static let sharedPaddleProductID   = "767777"
    private static let sharedPaddleAPIKey      = "17a505c6ae7872dee48ffb022fec1575"
    private static var sharedProductConfig     : PADProductConfiguration = {
        let productConfig = PADProductConfiguration()
        productConfig.productName = "JSTColorPicker (1 year)"
        productConfig.vendorName = "82Flex"
        productConfig.currency = "USD"
        productConfig.price = 14.99
        productConfig.trialType = .none
        return productConfig
    }()
        
    #endif
    
    // Initialize the SDK singleton with the config
    internal lazy var paddle: Paddle = {
        return Paddle.sharedInstance(
            withVendorID: Self.sharedPaddleVendorID,
            apiKey: Self.sharedPaddleAPIKey,
            productID: Self.sharedPaddleProductID,
            configuration: Self.sharedProductConfig,
            delegate: self
        )!
    }()
    
    // Initialize the Product you'd like to work with
    internal lazy var paddleProduct: PADProduct = {
        let product = PADProduct(
            productID: Self.sharedPaddleProductID,
            productType: PADProductType.sdkProduct,
            configuration: Self.sharedProductConfig
        )!
        product.delegate = self
        return product
    }()
    
#endif
    
    private var internalLock = ReadWriteLock()
    private var verificationDetails               : [AnyHashable: Any]?
    private var isTrial                           : Bool
    private var productType                       : ProductType = .uninitialized {
        didSet {
            NotificationCenter.default.post(name: PurchaseManager.productTypeDidChangeNotification, object: self)
        }
    }
    internal func getProductType() -> ProductType {
        var retVal: ProductType
        internalLock.readLock()
        retVal = self.productType
        internalLock.unlock()
        return retVal
    }
    
    #if APP_STORE
    private var expiredAt                         : Date?
    internal func getExpiryDate() -> Date? {
        var retVal: Date?
        internalLock.readLock()
        retVal = self.expiredAt
        internalLock.unlock()
        return retVal
    }
    #else
    internal var expiredAt                        : Date? { paddleProduct.licenseExpiryDate }
    #endif
    
    private static var shortExpiryDateFormatter   : DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    private static var mediumExpiryDateFormatter  : DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    internal func getShortReadableExpiredAt() -> String {
        var retVal: String
        internalLock.readLock()
        if let expiredAt = expiredAt {
            retVal = PurchaseManager.shortExpiryDateFormatter.string(from: expiredAt)
        } else {
            retVal = NSLocalizedString("Unlimited", comment: "getShortReadableExpiredAt()")
        }
        internalLock.unlock()
        return retVal
    }
    
    internal func getMediumReadableExpiredAt() -> String {
        var retVal: String
        internalLock.readLock()
        if let expiredAt = expiredAt {
            retVal = PurchaseManager.mediumExpiryDateFormatter.string(from: expiredAt)
        } else {
            retVal = NSLocalizedString("Unlimited", comment: "getShortReadableExpiredAt()")
        }
        internalLock.unlock()
        return retVal
    }
    
    override init() {
        
        guard internalLock.tryWriteLock() else {
            fatalError("unable to initialize PurchaseManager")
        }
        
#if APP_STORE
        self.isTrial = false
        self.expiredAt = Date()
#else  // !APP_STORE
#if DEBUG
        Paddle.enableDebug()
        Paddle.setEnvironmentToSandbox()
#endif  // DEBUG
        
        self.isTrial = false
#endif  // APP_STORE
        
        super.init()
        
#if !APP_STORE
        _ = { self.paddle }()
#endif  // !APP_STORE
        
        internalLock.unlock()
    }
    
    func tryDemoVersion() {
        internalLock.writeLock()
        if productType == .uninitialized {
            productType = .demoVersion
            debugPrint("tryDemoVersion()")
        }
        internalLock.unlock()
    }
    
    #if APP_STORE
    
    @discardableResult
    func loadLocalReceipt(withResult result: VerifySubscriptionResult? = nil) throws -> InAppPurchase {
        let receipt = try InAppReceipt.localReceipt()
        try receipt.validate()
        guard receipt.hasPurchases else { throw Error.notPurchased }
        guard let lastPurchase = receipt.autoRenewablePurchases
                .filter({ $0.subscriptionExpirationDate != nil })
                .sorted(by: { $0.subscriptionExpirationDate! > $1.subscriptionExpirationDate! })
                .first
        else {
            if internalLock.tryWriteLock() {
                productType = .uninitialized
                internalLock.unlock()
            }
            throw Error.invalidPurchase
        }
        
        // Extra validation between remote and local receipts
        if let remoteResult = result {
            switch remoteResult {
            case let .purchased(expiryDate, items):
                guard abs(expiryDate.timeIntervalSinceReferenceDate - lastPurchase.subscriptionExpirationDate!.timeIntervalSinceReferenceDate) < 60.0
                else {
                    if internalLock.tryWriteLock() {
                        productType = .uninitialized
                        internalLock.unlock()
                    }
                    throw Error.invalidPurchase
                }
                guard let lastReceipt = items
                        .filter({ $0.subscriptionExpirationDate != nil })
                        .sorted(by: { $0.subscriptionExpirationDate! > $1.subscriptionExpirationDate! })
                        .first,
                      lastReceipt.productId == PurchaseManager.sharedProductID,
                      (expiryDate.timeIntervalSinceReferenceDate - lastReceipt.subscriptionExpirationDate!.timeIntervalSinceReferenceDate) < 60.0
                else {
                    if internalLock.tryWriteLock() {
                        productType = .uninitialized
                        internalLock.unlock()
                    }
                    throw Error.invalidPurchase
                }
            default:
                if internalLock.tryWriteLock() {
                    productType = .uninitialized
                    internalLock.unlock()
                }
                throw Error.notPurchased
            }
        }
        
        // Setup state from last valid purchase
        let expiryDate = lastPurchase.subscriptionExpirationDate!
        
        internalLock.writeLock()
        expiredAt = expiryDate
        isTrial = lastPurchase.subscriptionTrialPeriod
        productType = expiryDate > Date() ? .subscribed : .expired
        internalLock.unlock()
        
        return lastPurchase
    }
    
    #else
    
    typealias PaddleVerificationCallback = (PADVerificationState, Swift.Error?, [AnyHashable: Any]?) throws -> Void
    
    func loadLocalReceipt(
        verifyActivationWithCompletion completion: PaddleVerificationCallback? = nil
    ) throws {
        
        guard paddleProduct.activated else {
            throw Error.notPurchased
        }
        
        guard let _activationDate = paddleProduct.activationDate,
              Date() > _activationDate,
              paddleProduct.productID == Self.sharedPaddleProductID,
              paddleProduct.productType == .sdkProduct
        else {
            if internalLock.tryWriteLock() {
                productType = .uninitialized
                internalLock.unlock()
            }
            throw Error.invalidPurchase
        }
        
        // Setup state from last valid purchase
        internalLock.writeLock()
        productType = .subscribed
        if paddleProduct.trialType == .none {
            isTrial = false
        } else if let trialStartDate = paddleProduct.trialStartDate,
                  Date() > trialStartDate,
                  let trialLength = paddleProduct.trialLength,
                  trialLength.intValue > 0,
                  let trialDaysRemaining = paddleProduct.trialDaysRemaining,
                  trialDaysRemaining.intValue > 0
        {
            isTrial = true
        } else {
            isTrial = false
        }
        internalLock.unlock()
        
        // Perform verification afterwards, for valid license only
        var shouldVerify = true
        var forceVerify = false
        
        if completion == nil, let lastVerifiedAt = paddleProduct.lastSuccessfulVerifiedDate {
            let verifyDistance = lastVerifiedAt.distance(to: Date())
            if verifyDistance < 7200 {
                // has verified in last 2 hours
                shouldVerify = false
            } else if verifyDistance > 2_592_000 {
                // did not pass verification in last month
                shouldVerify = true
                forceVerify = true
            }
        }
        
        if shouldVerify {
            
            let callback = completion ?? { [weak self] (state, error, details) in
                guard let self = self else { return }
                switch state {
                case .verified:
                    if let details = details {
                        if self.internalLock.tryWriteLock() {
                            self.verificationDetails = details
                            self.internalLock.unlock()
                        }
                    }
                case .unverified, .noActivation, .unableToVerify:
                    if forceVerify {
                        // deactivate current session
                        if self.internalLock.tryWriteLock() {
                            self.productType = .uninitialized
                            if let details = details {
                                self.verificationDetails = details
                            }
                            self.internalLock.unlock()
                        }
                    }
                    throw PurchaseController.Error(verificationState: state)!
                @unknown default:
                    fatalError()
                }
                if let error = error {
                    // other unknown error
                    throw PurchaseController.Error.other(description: error.localizedDescription)
                }
            }
            
            DispatchQueue.main.async { [unowned self] in
                self.paddleProduct.verifyActivationDetails {
                    if forceVerify {
                        do {
                            try callback($0, $1, $2)
                        } catch {
                            let alert = NSAlert(
                                style: .critical,
                                text: .init(
                                    message: NSLocalizedString("Subscription Requires Validation", comment: "loadLocalReceipt(verifyActivationWithCompletion:)"),
                                    information: error.localizedDescription
                                )
                            )
                            
                            alert.addButton(withTitle: NSLocalizedString("Deactivate…", comment: "loadLocalReceipt(verifyActivationWithCompletion:)"))
                            alert.addButton(withTitle: NSLocalizedString("Exit", comment: "loadLocalReceipt(verifyActivationWithCompletion:)"))
                            
                            let resp = alert.runModal()
                            if resp == .alertFirstButtonReturn
                            {
                                PurchaseWindowController.shared.showWindow(self)
                                NotificationCenter.default.post(
                                    name: PurchaseManager.productForceDeactivateNotification,
                                    object: nil
                                )
                            }
                            else if resp == .alertSecondButtonReturn
                            {
                                NSApp.terminate(self)
                            }
                        }
                    } else {
                        try? callback($0, $1, $2)
                    }
                }
            }
        }
    }
    
    #endif
    
    #if APP_STORE
    func verifySubscriptionState(_ result: VerifySubscriptionResult) throws {
        switch result {
        case .purchased(let expiryDate, _):
            let lastPurchase = try loadLocalReceipt(withResult: result)
            internalLock.writeLock()
            expiredAt = expiryDate
            isTrial = lastPurchase.subscriptionTrialPeriod
            productType = expiryDate > Date() ? .subscribed : .expired
            debugPrint("verifySubscriptionState(): valid, expiredAt = \(expiryDate), isTrail = \(lastPurchase.subscriptionTrialPeriod)")
            internalLock.unlock()
        case .expired(let expiryDate, let items):
            guard let lastReceipt = items
                    .filter({ $0.subscriptionExpirationDate != nil })
                    .sorted(by: { $0.subscriptionExpirationDate! > $1.subscriptionExpirationDate! })
                    .first,
                  lastReceipt.productId == PurchaseManager.sharedProductID
            else {
                if internalLock.tryWriteLock() {
                    productType = .uninitialized
                    internalLock.unlock()
                }
                throw Error.invalidPurchase
            }
            internalLock.writeLock()
            expiredAt = expiryDate
            isTrial = false
            productType = .expired
            debugPrint("verifySubscriptionState(): expired, expiredAt = \(expiryDate)")
            internalLock.unlock()
            throw Error.expired(at: expiryDate)
        case .notPurchased:
            if internalLock.tryWriteLock() {
                productType = .uninitialized
                internalLock.unlock()
            }
            throw Error.notPurchased
        }
    }
    #endif
    
    func readLock() {
        internalLock.readLock()
    }
    
    func tryReadLock() -> Bool {
        return internalLock.tryReadLock()
    }
    
    func unlock() {
        internalLock.unlock()
    }
    
    func setupTransactions() {
        
        if PurchaseManager.shared.getProductType() != .subscribed {
            PurchaseWindowController.shared.showWindow(self)
        }
        
#if APP_STORE
        
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
}

#if !APP_STORE
extension PurchaseManager: PaddleDelegate, PADProductDelegate {
    
    private static var licenseStorageURL: URL = {
        let url = AppDelegate.supportDirectoryURL.appendingPathComponent("Paddle")
        
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        return url
    }()
    
    func customStoragePath() -> String? {
        return PurchaseManager.licenseStorageURL.path
    }
    
    func willShowPaddle(_ uiType: PADUIType, product: PADProduct) -> PADDisplayConfiguration? {
        guard PurchaseWindowController.sharedLoaded else {
            return nil
        }
        if uiType == .checkout {
            return PADDisplayConfiguration(
                displayType: .sheet,
                hideNavigationButtons: true,
                parentWindow: PurchaseWindowController.shared.window
            )
        }
        return PADDisplayConfiguration.displayCustom()
    }
    
    func productDidUpdateRemotely(_ productDelta: [AnyHashable : Any]) {
        if !productDelta.isEmpty {
            debugPrint(productDelta)
        }
    }
    
    func productActivated() {
        try? loadLocalReceipt()
    }
    
    func productDeactivated() {
        if internalLock.tryWriteLock() {
            productType = .uninitialized
            debugPrint("productDeactivated(): deactivated")
            internalLock.unlock()
        }
        NotificationCenter.default.post(name: Self.productDeactivatedNotification, object: self)
    }
    
    func productPurchased(_ checkoutData: PADCheckoutData) {
        debugPrint(checkoutData)
    }
    
}
#endif
