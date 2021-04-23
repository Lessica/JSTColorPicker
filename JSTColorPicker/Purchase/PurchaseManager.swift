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

@objc class PurchaseManager: NSObject {
    
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
                    PurchaseManager.expiryDateFormatter.string(from: at)
                )
            }
        }
    }
    
    static var shared          = PurchaseManager()
    static let sharedProductID = "com.jst.JSTColorPicker.Subscription.Yearly"
    static let sharedSecret    = "53cbec8e68f445c596ce0c3e059a1f06"
    
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
    
    static let productTypeDidChangeNotification = Notification.Name("PurchaseManager.productTypeDidChangeNotification")
    private(set) var productType  : ProductType = .uninitialized {
        didSet {
            NotificationCenter.default.post(name: PurchaseManager.productTypeDidChangeNotification, object: self)
        }
    }
    
    var readableExpiredAt: String { PurchaseManager.expiryDateFormatter.string(from: expiredAt) }
    private(set)   var expiredAt          : Date
    private static var expiryDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    private(set) var isTrial      : Bool
    
    override init() {
        self.expiredAt = Date()
        self.isTrial = false
        super.init()
    }
    
    func tryDemoVersion() {
        if productType == .uninitialized {
            productType = .demoVersion
            debugPrint("tryDemoVersion()")
        }
    }
    
    var hasLocalReceipt: Bool { SwiftyStoreKit.localReceiptData != nil }
    
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
            productType = .uninitialized
            throw Error.invalidPurchase
        }
        // Extra validation between remote and local receipts
        if let remoteResult = result {
            switch remoteResult {
            case let .purchased(expiryDate, items):
                guard abs(expiryDate.timeIntervalSinceReferenceDate - lastPurchase.subscriptionExpirationDate!.timeIntervalSinceReferenceDate) < 60.0
                else {
                    productType = .uninitialized
                    throw Error.invalidPurchase
                }
                guard let lastReceipt = items
                        .filter({ $0.subscriptionExpirationDate != nil })
                        .sorted(by: { $0.subscriptionExpirationDate! > $1.subscriptionExpirationDate! })
                        .first,
                      lastReceipt.productId == PurchaseManager.sharedProductID,
                      (expiryDate.timeIntervalSinceReferenceDate - lastReceipt.subscriptionExpirationDate!.timeIntervalSinceReferenceDate) < 60.0
                else {
                    productType = .uninitialized
                    throw Error.invalidPurchase
                }
            default:
                productType = .uninitialized
                throw Error.notPurchased
            }
        }
        // Setup state from last valid purchase
        let expiryDate = lastPurchase.subscriptionExpirationDate!
        expiredAt = expiryDate
        isTrial = lastPurchase.subscriptionTrialPeriod
        productType = expiryDate > Date() ? .subscribed : .expired
        return lastPurchase
    }
    
    func trySubscribe(_ result: VerifySubscriptionResult) throws {
        switch result {
        case .purchased(let expiryDate, _):
            let lastPurchase = try loadLocalReceipt(withResult: result)
            expiredAt = expiryDate
            isTrial = lastPurchase.subscriptionTrialPeriod
            productType = expiryDate > Date() ? .subscribed : .expired
            debugPrint("trySubscribe(): valid, expiredAt = \(expiryDate), isTrail = \(lastPurchase.subscriptionTrialPeriod)")
        case .expired(let expiryDate, let items):
            guard let lastReceipt = items
                    .filter({ $0.subscriptionExpirationDate != nil })
                    .sorted(by: { $0.subscriptionExpirationDate! > $1.subscriptionExpirationDate! })
                    .first,
                  lastReceipt.productId == PurchaseManager.sharedProductID
            else {
                productType = .uninitialized
                throw Error.invalidPurchase
            }
            expiredAt = expiryDate
            isTrial = false
            productType = .expired
            debugPrint("trySubscribe(): expired, expiredAt = \(expiryDate)")
            throw Error.expired(at: expiryDate)
        case .notPurchased:
            productType = .uninitialized
            throw Error.notPurchased
        }
    }
    
}
