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
    
    static let productTypeDidChangeNotification  = Notification.Name("PurchaseManager.productTypeDidChangeNotification")
    
    enum Error: LocalizedError {
        case invalidReceipt
        case invalidPurchase
        case notPurchased
        case expired(at: Date)
        
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
    
    static var shared                  = PurchaseManager()
    
#if APP_STORE
    static let channelName             = "App Store"
    static let sharedProductID         = "com.jst.JSTColorPicker.Subscription.Yearly"
    static let sharedSecret            = "53cbec8e68f445c596ce0c3e059a1f06"
#else
    static let channelName             = "Paddle.com"
    #if DEBUG
        
        // Your Paddle SDK Config from the Vendor Dashboard
        private static let sharedPaddleVendorID    = "5790"
        private static let sharedPaddleProductID   = "27345"
        private static let sharedPaddleAPIKey      = "b7f5f632ecdef9b9524a5f2fdd63990d"
        private static var sharedProductConfig     : PADProductConfiguration = {
            let productConfig = PADProductConfiguration()
            productConfig.productName = "JSTColorPicker Daily Subscription"
            productConfig.vendorName = "82Flex"
            productConfig.currency = "USD"
            productConfig.recurringPrice = 0
            productConfig.subscriptionPlanLength = 1
            productConfig.subscriptionPlanType = .day
            productConfig.subscriptionTrialLength = 0
            productConfig.trialType = .none
            return productConfig
        }()
        
    #else
        
        private static let sharedPaddleVendorID    = "145985"
        private static let sharedPaddleProductID   = "767646"
        private static let sharedPaddleAPIKey      = "17a505c6ae7872dee48ffb022fec1575"
        private static var sharedProductConfig     : PADProductConfiguration = {
            let productConfig = PADProductConfiguration()
            productConfig.productName = "JSTColorPicker Yearly Subscription"
            productConfig.vendorName = "82Flex"
            productConfig.currency = "USD"
            productConfig.recurringPrice = 14.99
            productConfig.subscriptionPlanLength = 1
            productConfig.subscriptionPlanType = .year
            productConfig.subscriptionTrialLength = 0
            productConfig.trialType = .none
            return productConfig
        }()
        
    #endif
    
    // Initialize the SDK singleton with the config
    lazy var paddle: Paddle = {
        return Paddle.sharedInstance(
            withVendorID: Self.sharedPaddleVendorID,
            apiKey: Self.sharedPaddleAPIKey,
            productID: Self.sharedPaddleProductID,
            configuration: Self.sharedProductConfig,
            delegate: self
        )!
    }()
    
    // Initialize the Product you'd like to work with
    lazy var paddleProduct: PADProduct = {
        let product = PADProduct(
            productID: Self.sharedPaddleProductID,
            productType: PADProductType.subscriptionPlan,
            configuration: Self.sharedProductConfig
        )!
        product.delegate = self
        return product
    }()
    
    @Published private(set) var activationEmail   : String?
    func getActivationEmail() -> String? {
        var retVal: String?
        internalLock.readLock()
        retVal = self.activationEmail
        internalLock.unlock()
        return retVal
    }
    
#endif
    
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
    
    @Published private(set) var productType       : ProductType = .uninitialized {
        didSet {
            NotificationCenter.default.post(name: PurchaseManager.productTypeDidChangeNotification, object: self)
        }
    }
    func getProductType() -> ProductType {
        var retVal: ProductType
        internalLock.readLock()
        retVal = self.productType
        internalLock.unlock()
        return retVal
    }
    
    @Published private(set) var expiredAt         : Date
    func getExpiryDate() -> Date {
        var retVal: Date
        internalLock.readLock()
        retVal = self.expiredAt
        internalLock.unlock()
        return retVal
    }
    func getShortReadableExpiredAt() -> String {
        var retVal: String
        internalLock.readLock()
        retVal = PurchaseManager.shortExpiryDateFormatter.string(from: expiredAt)
        internalLock.unlock()
        return retVal
    }
    func getMediumReadableExpiredAt() -> String {
        var retVal: String
        internalLock.readLock()
        retVal = PurchaseManager.mediumExpiryDateFormatter.string(from: expiredAt)
        internalLock.unlock()
        return retVal
    }
    
    @Published private(set) var isTrial           : Bool
    private var internalLock  = ReadWriteLock()
    
    override init() {
        guard internalLock.tryWriteLock() else {
            fatalError("unable to initialize PurchaseManager")
        }
        self.expiredAt = Date()
        self.isTrial = false
        super.init()
#if !APP_STORE
        #if DEBUG
        Paddle.enableDebug()
        Paddle.setEnvironmentToSandbox()
        #endif
        _ = { self.paddle }()
#endif
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
    @discardableResult
    func loadLocalReceipt(
        verifyActivationWithCompletion completion: ((PADVerificationState, Swift.Error?, [AnyHashable: Any]?) throws -> Void)? = nil
    ) throws -> PADProduct
    {
        guard paddleProduct.activated else {
            throw Error.notPurchased
        }
        
        guard let email = paddleProduct.activationEmail,
              let expiryDate = paddleProduct.licenseExpiryDate,
              paddleProduct.productType == .subscriptionPlan,
              paddleProduct.productID == Self.sharedPaddleProductID
        else {
            if internalLock.tryWriteLock() {
                productType = .uninitialized
                internalLock.unlock()
            }
            throw Error.invalidPurchase
        }
        
        // Setup state from last valid purchase
        let notExpired = expiryDate > Date()
        internalLock.writeLock()
        expiredAt = expiryDate
        isTrial = (paddleProduct.trialDaysRemaining?.intValue ?? 0) > 0
        activationEmail = email
        productType = notExpired ? .subscribed : .expired
        internalLock.unlock()
        
        // Ignore expired license
        guard notExpired else {
            debugPrint("loadLocalReceipt(verifyActivationWithCompletion:): expired, expiredAt = \(expiryDate)")
            throw Error.expired(at: expiryDate)
        }
        
        debugPrint("verifySubscriptionState(verifyActivationWithCompletion:): valid, expiredAt = \(expiryDate), isTrail = \(isTrial)")
        
        // Perform verification afterwards, for valid license only
        var shouldVerify = true
        if completion == nil, let lastVerifiedAt = paddleProduct.lastSuccessfulVerifiedDate {
            let verifyDistance = Date().distance(to: lastVerifiedAt)
            if verifyDistance > 7200 {
                // has verified in last 2 hours
                shouldVerify = false
            }
        }
        
        if shouldVerify {
            let callback = completion ?? verifySubscriptionState
            paddleProduct.verifyActivationDetails {
                try? callback($0, $1, $2)
            }
        }
        
        return paddleProduct
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
    #else
    private func verifySubscriptionState(
        _ state: PADVerificationState,
        _ error: Swift.Error?,
        _ details: [AnyHashable: Any]?
    ) throws
    {
        if let details = details {
            debugPrint(details)
        }
        if let error = error {
            // unknown error
            throw error
        }
        switch state {
            case .verified:
                break
            case .unverified, .noActivation, .unableToVerify:
                if internalLock.tryWriteLock() {
                    productType = .uninitialized
                    internalLock.unlock()
                }
                throw Error.notPurchased
            @unknown default:
                fatalError()
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
        let url = FileManager
            .default
            .urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )
            .first!
            .appendingPathComponent(Bundle.main.bundleIdentifier!)
            .appendingPathComponent("Paddle")
        
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
        fatalError("not implemented")
    }
    
    func productDeactivated() {
        fatalError("not implemented")
    }
    
    func productPurchased(_ checkoutData: PADCheckoutData) {
        fatalError("not implemented")
    }
    
}
#endif
