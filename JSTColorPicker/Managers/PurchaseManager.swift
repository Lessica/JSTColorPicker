//
//  PurchaseManager.swift
//  JSTColorPicker
//
//  Created by Rachel on 4/23/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Foundation
import SwiftyStoreKit
import TPInAppReceipt

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
                return NSLocalizedString("Not purchased.", comment: "PurchaseController.Error")
            case let .expired(at):
                return String(
                    format: NSLocalizedString("Your previous subscription has expired since %@. Please renew your subscription.", comment: "PurchaseController.Error"),
                    PurchaseManager.mediumExpiryDateFormatter.string(from: at)
                )
            }
        }
    }
    
    static var shared              = PurchaseManager()
    static let sharedProductID     = "com.jst.JSTColorPicker.Subscription.Yearly"
    static let sharedSecret        = "53cbec8e68f445c596ce0c3e059a1f06"
    
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
    
    private static var shortExpiryDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    private static var mediumExpiryDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    private        var productType   : ProductType = .uninitialized {
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
    
    private        var expiredAt     : Date
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
    
    private        var isTrial       : Bool
    private        var internalLock  = ReadWriteLock()
    
    override init() {
        guard internalLock.tryWriteLock() else {
            fatalError("unable to initialize PurchaseManager")
        }
        self.expiredAt = Date()
        self.isTrial = false
        super.init()
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
    
    @discardableResult
    func loadLocalReceipt(withResult result: VerifySubscriptionResult? = nil) throws -> InAppPurchase {
        let receipt = try InAppReceipt.localReceipt()
        try receipt.verify()
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
    
    func trySubscribe(_ result: VerifySubscriptionResult) throws {
        switch result {
        case .purchased(let expiryDate, _):
            let lastPurchase = try loadLocalReceipt(withResult: result)
            internalLock.writeLock()
            expiredAt = expiryDate
            isTrial = lastPurchase.subscriptionTrialPeriod
            productType = expiryDate > Date() ? .subscribed : .expired
            debugPrint("trySubscribe(): valid, expiredAt = \(expiryDate), isTrail = \(lastPurchase.subscriptionTrialPeriod)")
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
            debugPrint("trySubscribe(): expired, expiredAt = \(expiryDate)")
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
    
    func readLock() {
        internalLock.readLock()
    }
    
    func tryReadLock() -> Bool {
        return internalLock.tryReadLock()
    }
    
    func unlock() {
        internalLock.unlock()
    }
    
}
