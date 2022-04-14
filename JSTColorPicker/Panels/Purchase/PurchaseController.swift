//
//  PurchaseController.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/20.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa
import SwiftyStoreKit

final class PurchaseController: NSViewController {
    
    enum Error: LocalizedError {
        case invalidProductIdentifier(identifier: String)
        case nothingToRestore
        case other(description: String)
        
        var failureReason: String? {
            switch self {
            case let .invalidProductIdentifier(identifier):
                return String(format: NSLocalizedString("Invalid product identifier: “%@”.", comment: "PurchaseController.Error"), identifier)
            case .nothingToRestore:
                return NSLocalizedString("Nothing to restore.", comment: "PurchaseController.Error")
            case let .other(description):
                return description
            }
        }
    }
    
    @IBOutlet weak var titleLabel            : NSTextField!
    @IBOutlet weak var subtitleLabel         : NSTextField!
    
    @IBOutlet weak var mainView              : PurchaseMainView!
    @IBOutlet weak var thankYouView          : NSView!
    @IBOutlet weak var iconView              : NSView!
    @IBOutlet weak var topView               : NSView!
    @IBOutlet weak var topLine               : NSBox!
    @IBOutlet weak var middleView            : NSView!
    @IBOutlet weak var bottomLine            : NSBox!
    @IBOutlet weak var bottomView            : NSView!
    
    @IBOutlet weak var trialButton           : PurchaseButton!
    @IBOutlet weak var buyButton             : PurchaseButton!
    @IBOutlet weak var restoreButton         : PurchaseButton!
    @IBOutlet weak var checkUpdatesButton    : NSButton!
    @IBOutlet weak var termsAndPrivacyButton : NSButton!
    @IBOutlet weak var visitWebsiteButton    : NSButton!
    
    @IBOutlet weak var maskView              : ColoredView!
    @IBOutlet weak var maskIndicator         : NSProgressIndicator!
    
    private        var isMasked              : Bool = false
    {
        didSet {
            [
                trialButton,
                buyButton,
                restoreButton,
            ].forEach({ $0?.isEnabled = !isMasked })
            maskView.isHidden = !isMasked
            if isMasked {
                maskIndicator.startAnimation(self)
            } else {
                maskIndicator.stopAnimation(self)
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        #if APP_STORE
        checkUpdatesButton.isHidden = true
        termsAndPrivacyButton.isHidden = false
        #else
        checkUpdatesButton.isHidden = false
        termsAndPrivacyButton.isHidden = true
        #endif
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        reloadUI()
        if PurchaseManager.shared.getProductType() != .subscribed {
            reloadProductsUI()
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(productTypeDidChange(_:)),
            name: PurchaseManager.productTypeDidChangeNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func reloadUI() {
        if PurchaseManager.shared.getProductType() == .subscribed {
            mainView.material = .hudWindow
            thankYouView.isHidden = false
            iconView.isHidden = true
            titleLabel.stringValue = NSLocalizedString("Thank you!", comment: "reloadUI()")
            subtitleLabel.attributedStringValue = String(
                format: NSLocalizedString("Thank you for purchasing JSTColorPicker from App Store. You are awesome!\n\n**Subscription Expiry Date**: _%@_", comment: "reloadUI()"),
                PurchaseManager.shared.getMediumReadableExpiredAt()
            ).markdownAttributed
            topView.isHidden = false
            middleView.isHidden = true
            bottomView.isHidden = false
            topLine.isHidden = true
            bottomLine.isHidden = false
        } else {
            mainView.material = .windowBackground
            thankYouView.isHidden = true
            iconView.isHidden = false
            titleLabel.stringValue = NSLocalizedString("Welcome", comment: "reloadUI()")
            subtitleLabel.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .regular))
            subtitleLabel.stringValue = NSLocalizedString("Thank you for downloading JSTColorPicker!", comment: "reloadUI()")
            topView.isHidden = false
            middleView.isHidden = false
            bottomView.isHidden = false
            topLine.isHidden = false
            bottomLine.isHidden = false
        }
    }
    
    private func reloadProductsUI() {
        self.isMasked = true
        SwiftyStoreKit.retrieveProductsInfo([PurchaseManager.sharedProductID]) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                do {
                    if let product = result.retrievedProducts.first {
                        self.buyButton.isEnabled = true
                        self.buyButton.subtitleLabel.stringValue = product.localizedDescription
                        if let priceString = product.localizedPrice {
                            let periodString = product.localizedSubscriptionPeriod
                            self.buyButton.priceLabel?.stringValue = String(format: NSLocalizedString("%@/%@", comment: "reloadProductsUI()"), priceString, periodString)
                            self.buyButton.priceLabel?.isHidden = false
                        } else {
                            self.buyButton.priceLabel?.isHidden = true
                        }
                    }
                    else if let invalidProductId = result.invalidProductIDs.first {
                        throw Error.invalidProductIdentifier(identifier: invalidProductId)
                    }
                    else if let error = result.error {
                        throw error
                    }
                } catch {
                    self.buyButton.isEnabled = false
                    self.buyButton.priceLabel?.isHidden = true
                    self.presentError(error)
                }
                self.isMasked = false
            }
        }
    }
    
    private func tryDemoVersion() {
        guard let window = view.window else { return }
        window.cancelOperation(self)
    }
    
    private func makeNewSubscription() {
        var isSandbox = false
        #if DEBUG
        isSandbox = true
        #endif
        self.isMasked = true
        SwiftyStoreKit.purchaseProduct(
            PurchaseManager.sharedProductID,
            quantity: 1,
            atomically: true,
            simulatesAskToBuyInSandbox: isSandbox
        ) { [weak self] result in
            guard let self = self else { return }
            do {
                switch result {
                case .success(let purchase):
                    if purchase.needsFinishTransaction {
                        SwiftyStoreKit.finishTransaction(purchase.transaction)
                    }
                    debugPrint("Purchase Succeed: \(purchase.productId)")
                    self._validateSubscription { [weak self] (succeed, error) in
                        guard let self = self else { return }
                        if let error = error {
                            DispatchQueue.main.async {
                                self.presentError(error)
                                self.isMasked = false
                            }
                            return
                        }
                        DispatchQueue.main.async {
                            self.isMasked = false
                        }
                    }
                case .error(let error):
                    if error.code != .paymentCancelled {
                        throw error
                    }
                    DispatchQueue.main.async {
                        self.isMasked = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.presentError(error)
                    self.isMasked = false
                }
            }
        }
    }
    
    private func restoreSubscription() {
        self.isMasked = true
        SwiftyStoreKit.restorePurchases(atomically: true) { [weak self] results in
            guard let self = self else { return }
            do {
                var succeedPurchases: [Purchase]?
                let failedPurchases = results.restoreFailedPurchases.filter({ $0.1 == PurchaseManager.sharedProductID })
                if let error = failedPurchases.first?.0 {
                    throw error
                } else if let succeedPurchase = results.restoredPurchases.last, succeedPurchase.productId == PurchaseManager.sharedProductID {
                    debugPrint("Restore Succeed: \(succeedPurchase.productId)")
                    succeedPurchases = results.restoredPurchases
                } else {
                    if failedPurchases.isEmpty {
                        debugPrint("Nothing to restore.")
                    } else {
                        throw Error.nothingToRestore
                    }
                }
                if let purchasesToFinish = succeedPurchases?.filter({ $0.needsFinishTransaction }) {
                    purchasesToFinish.forEach({ SwiftyStoreKit.finishTransaction($0.transaction) })
                }
                self._validateSubscription { [weak self] (succeed, error) in
                    guard let self = self else { return }
                    if let error = error {
                        DispatchQueue.main.async {
                            self.presentError(error)
                            self.isMasked = false
                        }
                        return
                    }
                    DispatchQueue.main.async {
                        self.isMasked = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.presentError(error)
                    self.isMasked = false
                }
            }
        }
    }
    
    private func _validateSubscription(completionHandler completion: @escaping (Bool, Swift.Error?) -> Void) {
        var urlType: AppleReceiptValidator.VerifyReceiptURLType
        #if DEBUG
        urlType = .sandbox
        #else
        urlType = .production
        #endif
        let appleValidator = AppleReceiptValidator(service: urlType, sharedSecret: PurchaseManager.sharedSecret)
        SwiftyStoreKit.verifyReceipt(using: appleValidator) { result in
            do {
                switch result {
                case .success(let receipt):
                    let productId = PurchaseManager.sharedProductID
                    // Verify the purchase of a Subscription
                    let purchaseResult = SwiftyStoreKit.verifySubscription(
                        ofType: .autoRenewable, // or .nonRenewing (see below)
                        productId: productId,
                        inReceipt: receipt
                    )
                    try PurchaseManager.shared.trySubscribe(purchaseResult)
                    completion(true, nil)
                case .error(let error):
                    throw error
                }
            } catch {
                completion(false, error)
            }
        }
    }
    
    private func fetchExistingReceipt(forceRefresh force: Bool) {
        self.isMasked = true
        SwiftyStoreKit.fetchReceipt(forceRefresh: force) { [weak self] result in
            guard let self = self else { return }
            do {
                switch result {
                case .success(let receiptData):
                    let encryptedReceipt = receiptData.base64EncodedString(options: [])
                    print("Fetch receipt success:\n\(encryptedReceipt)")
                    try PurchaseManager.shared.loadLocalReceipt()
                    DispatchQueue.main.async {
                        self.isMasked = false
                    }
                case .error(let error):
                    print("Fetch receipt failed: \(error)")
                    throw error
                }
            } catch {
                DispatchQueue.main.async {
                    self.presentError(error)
                    self.isMasked = false
                }
            }
        }
    }
    
}

extension PurchaseController: PurchaseButtonDelegate {
    
    func purchaseButtonTapped(_ sender: PurchaseButton) {
        if sender == trialButton {
            tryDemoVersion()
        }
        else if sender == buyButton {
            makeNewSubscription()
        }
        else if sender == restoreButton {
            restoreSubscription()
        }
    }
    
    @IBAction private func checkUpdatesButtonTapped(_ sender: NSButton) { }
    
    @IBAction private func termsAndPrivacyButtonTapped(_ sender: NSButton) {
        NSWorkspace.shared.redirectToTermsPage()
    }
    
    @IBAction private func visitWebsiteButtonTapped(_ sender: NSButton) {
        NSWorkspace.shared.redirectToMainPage()
    }
    
}

extension PurchaseController {
    
    @objc private func productTypeDidChange(_ noti: Notification) {
        DispatchQueue.main.async {
            self.reloadUI()
        }
    }
    
}
