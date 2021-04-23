//
//  PurchaseController.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/20.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa
import SwiftyStoreKit

class PurchaseController: NSViewController {
    
    enum Error: LocalizedError {
        case invalidProductIdentifier(identifier: String)
        case nothingToRestore
        case other(description: String)
        
        var failureReason: String? {
            switch self {
            case let .invalidProductIdentifier(identifier):
                return String(format: NSLocalizedString("Invalid product identifier: \"%@\".", comment: "PurchaseController.Error"), identifier)
            case .nothingToRestore:
                return NSLocalizedString("Nothing to restore.", comment: "PurchaseController.Error")
            case let .other(description):
                return description
            }
        }
    }
    
    @IBOutlet weak var titleLabel            : NSTextField!
    @IBOutlet weak var subtitleLabel         : NSTextField!
    
    @IBOutlet weak var topView               : NSView!
    @IBOutlet weak var topLine               : NSBox!
    @IBOutlet weak var middleView            : NSView!
    @IBOutlet weak var bottomLine            : NSBox!
    @IBOutlet weak var bottomView            : NSView!
    
    @IBOutlet weak var trialButton           : PurchaseButton!
    @IBOutlet weak var buyButton             : PurchaseButton!
    @IBOutlet weak var restoreButton         : PurchaseButton!
    @IBOutlet weak var checkUpdatesButton    : NSButton!
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
        #else
        checkUpdatesButton.isHidden = false
        #endif
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        reloadUI()
        if PurchaseManager.shared.productType != .subscribed {
            reloadProductsUI()
        }
    }
    
    private func reloadUI() {
        if PurchaseManager.shared.productType == .subscribed {
            titleLabel.stringValue = NSLocalizedString("Thank you!", comment: "reloadUI()")
            subtitleLabel.stringValue = String(
                format: NSLocalizedString("Thank you for purchasing JSTColorPicker from App Store. You are awesome!\nSubscription Expiry Date: %@", comment: "reloadUI()"),
                PurchaseManager.shared.readableExpiredAt
            )
            topView.isHidden = false
            middleView.isHidden = true
            bottomView.isHidden = false
            topLine.isHidden = true
            bottomLine.isHidden = false
        } else {
            titleLabel.stringValue = NSLocalizedString("Welcome", comment: "reloadUI()")
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
                            self.buyButton.priceLabel?.stringValue = priceString
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
        SwiftyStoreKit.purchaseProduct(PurchaseManager.sharedProductID, quantity: 1, atomically: true, simulatesAskToBuyInSandbox: isSandbox) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                do {
                    switch result {
                    case .success(let purchase):
                        debugPrint("Purchase Succeed: \(purchase.productId)")
                        self.validateSubscription()
                    case .error(let error):
                        if error.code != .paymentCancelled {
                            throw error
                        }
                    }
                } catch {
                    self.isMasked = false
                    self.presentError(error)
                }
            }
        }
    }
    
    private func restoreSubscription() {
        self.isMasked = true
        SwiftyStoreKit.restorePurchases(atomically: true) { [weak self] results in
            guard let self = self else { return }
            DispatchQueue.main.async {
                do {
                    let failedPurchases = results.restoreFailedPurchases.filter({ $0.1 == PurchaseManager.sharedProductID })
                    if let error = failedPurchases.first?.0 {
                        throw error
                    } else if let succeedPurchase = results.restoredPurchases.last, succeedPurchase.productId == PurchaseManager.sharedProductID {
                        debugPrint("Restore Succeed: \(succeedPurchase.productId)")
                        self.validateSubscription()
                    } else {
                        if failedPurchases.isEmpty && PurchaseManager.shared.hasLocalReceipt {
                            debugPrint("Nothing to restore.")
                            self.validateSubscription()
                        } else {
                            throw Error.nothingToRestore
                        }
                    }
                } catch {
                    self.isMasked = false
                    self.presentError(error)
                }
            }
        }
    }
    
    private func validateSubscription() {
        var urlType: AppleReceiptValidator.VerifyReceiptURLType
        #if DEBUG
        urlType = .sandbox
        #else
        urlType = .production
        #endif
        self.isMasked = true
        let appleValidator = AppleReceiptValidator(service: urlType, sharedSecret: PurchaseManager.sharedSecret)
        SwiftyStoreKit.verifyReceipt(using: appleValidator) { [weak self] result in
            guard let self = self else { return }
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
                    self.reloadUI()
                case .error(let error):
                    throw error
                }
            } catch {
                self.presentError(error)
            }
            self.isMasked = false
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
    
    @IBAction func checkUpdatesButtonTapped(_ sender: NSButton) {
        debugPrint("check updates")
    }
    
    @IBAction func visitWebsiteButtonTapped(_ sender: NSButton) {
        if let url = URL(string: "https://82flex.com/jstcpweb/") {
            NSWorkspace.shared.open(url)
        }
    }
    
}
