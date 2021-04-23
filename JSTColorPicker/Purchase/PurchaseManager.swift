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
        case notPurchased
        
        var failureReason: String? {
            switch self {
            case .invalidReceipt:
                return NSLocalizedString("Invalid receipt.", comment: "PurchaseManager.Error")
            case .notPurchased:
                return NSLocalizedString("Not purchased.", comment: "PurchaseController.Error")
            }
        }
    }
    
    class var shared: PurchaseManager { AppDelegate.shared.purchaseManager }
    static let sharedProductID = "com.jst.JSTColorPicker.Subscription.Yearly"
    static let sharedSecret    = "53cbec8e68f445c596ce0c3e059a1f06"
    
    enum ProductType: Int {
        case uninitialized
        case demoVersion
        case subscribed
        case expired
    }
    
    static let productTypeDidChangeNotification = Notification.Name("PurchaseManager.productTypeDidChangeNotification")
    private(set) var productType  : ProductType = .uninitialized {
        didSet {
            NotificationCenter.default.post(name: PurchaseManager.productTypeDidChangeNotification, object: self)
        }
    }
    
    private(set) var expiredAt    : Date
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
            throw Error.notPurchased
        }
        // Extra validation between remote and local receipts
        if let remoteResult = result {
            switch remoteResult {
            case let .purchased(expiryDate, items):
                guard abs(expiryDate.timeIntervalSinceReferenceDate - lastPurchase.subscriptionExpirationDate!.timeIntervalSinceReferenceDate) < 60.0
                else {
                    productType = .uninitialized
                    throw Error.notPurchased
                }
                guard let lastReceipt = items
                        .filter({ $0.subscriptionExpirationDate != nil })
                        .sorted(by: { $0.subscriptionExpirationDate! > $1.subscriptionExpirationDate! })
                        .first,
                      lastReceipt.productId == PurchaseManager.sharedProductID,
                      (expiryDate.timeIntervalSinceReferenceDate - lastReceipt.subscriptionExpirationDate!.timeIntervalSinceReferenceDate) < 60.0
                else {
                    productType = .uninitialized
                    throw Error.notPurchased
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
                throw Error.notPurchased
            }
            expiredAt = expiryDate
            isTrial = false
            productType = .expired
            debugPrint("trySubscribe(): expired, expiredAt = \(expiryDate)")
        case .notPurchased:
            productType = .uninitialized
            throw Error.notPurchased
        }
    }
    
}
