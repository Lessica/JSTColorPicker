//
//  PurchaseController.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/20.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa
#if APP_STORE
import SwiftyStoreKit
#else
import Paddle
#endif

final class PurchaseController: NSViewController {
    
    enum Error: LocalizedError {
        case invalidProductIdentifier(identifier: String)
        case nothingToRestore
        case checkoutFailed
        case checkoutFlagged
        case checkoutSlowOrderProcessing
        case validateNoActivation
        case validateUnableToVerify
        case unverified
        case other(description: String)
        
        var failureReason: String? {
            switch self {
                case let .invalidProductIdentifier(identifier):
                    return String(format: NSLocalizedString("Invalid product identifier: “%@”.", comment: "PurchaseController.Error"), identifier)
                case .nothingToRestore:
                    return NSLocalizedString("Nothing to restore.", comment: "PurchaseController.Error")
                case .checkoutFailed:
                    return NSLocalizedString("The checkout failed to load or the order processing took too long to complete.", comment: "PurchaseController.Error")
                case .checkoutFlagged:
                    return NSLocalizedString("The checkout was completed, but the transaction was flagged for manual processing. The Paddle team will handle the transaction manually. If the order is approved, the buyer will be able to activate the product later, when the approved order has been processed.", comment: "PurchaseController.Error")
                case .checkoutSlowOrderProcessing:
                    return NSLocalizedString("The checkout has been completed and the payment has been taken, but we were unable to retrieve the status of the order. It will be processed soon, but not soon enough for us to show the buyer the license activation dialog.", comment: "PurchaseController.Error")
                case .validateNoActivation:
                    return NSLocalizedString("There is no license to verify.", comment: "PurchaseController.Error")
                case .validateUnableToVerify:
                    return NSLocalizedString("We were unable to get a definitive verification result, typically because of poor network.", comment: "PurchaseController.Error")
                case .unverified:
                    return NSLocalizedString("The license did not pass verification.", comment: "PurchaseController.Error")
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
        restoreButton.subtitleLabel.stringValue = NSLocalizedString("Validate your subscription from Paddle.", comment: "PurchaseController")
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
    
    #if APP_STORE
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
                    
                    self.isMasked = false
                } catch {
                    self.buyButton.isEnabled = false
                    self.buyButton.priceLabel?.isHidden = true
                    
                    if let window = self.view.window {
                        let alert = NSAlert(error: error)
                        alert.beginSheetModal(for: window) { _ in
                            self.isMasked = false
                        }
                    } else {
                        self.isMasked = false
                    }
                    
                }
            }
        }
    }
    #else
    private func _refreshPaddleProductUI() {
        let product = PurchaseManager.shared.paddleProduct
        self.buyButton.isEnabled = true
        if let priceCurrency = product.currency,
           let priceNumber = product.currentPrice
        {
            if priceNumber.doubleValue < 0.01 {
                self.buyButton.priceLabel?.stringValue = NSLocalizedString("Free", comment: "reloadProductsUI()")
            } else {
                var periodString: String
                switch product.subscriptionPlanType {
                    case .year:
                        periodString = NSLocalizedString("year", comment: "_refreshPaddleProductUI()")
                    case .month:
                        periodString = NSLocalizedString("month", comment: "_refreshPaddleProductUI()")
                    case .week:
                        periodString = NSLocalizedString("week", comment: "_refreshPaddleProductUI()")
                    case .day:
                        periodString = NSLocalizedString("day", comment: "_refreshPaddleProductUI()")
                    @unknown default:
                        periodString = NSLocalizedString("year", comment: "_refreshPaddleProductUI()")
                }
                self.buyButton.priceLabel?.stringValue = String(format: NSLocalizedString("%@ %@/%@", comment: "reloadProductsUI()"), priceCurrency, priceNumber, periodString)
            }
            
            self.buyButton.priceLabel?.isHidden = false
        } else {
            self.buyButton.priceLabel?.isHidden = true
        }
    }
    private func reloadProductsUI() {
        self.isMasked = true
        let product = PurchaseManager.shared.paddleProduct
        product.refresh { [weak self] (delta, error) in
            guard let self = self else { return }
            if let error = error {
                self.buyButton.isEnabled = false
                self.buyButton.priceLabel?.isHidden = true
                
                if let window = self.view.window {
                    let alert = NSAlert(error: error)
                    alert.beginSheetModal(for: window) { _ in
                        self.isMasked = false
                    }
                } else {
                    self.isMasked = false
                }
            } else {
                self._refreshPaddleProductUI()
                self.isMasked = false
            }
        }
    }
    #endif
    
    private func tryDemoVersion() {
        guard let window = view.window else { return }
        window.cancelOperation(self)
    }
    
    #if APP_STORE
    private func makeNewSubscription() {
        guard let window = self.view.window else { return }
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
                                let alert = NSAlert(error: error)
                                alert.beginSheetModal(for: window) { _ in
                                    self.isMasked = false
                                }
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
                    let alert = NSAlert(error: error)
                    alert.beginSheetModal(for: window) { _ in
                        self.isMasked = false
                    }
                }
            }
        }
    }
    #else
    private func makeNewSubscription() {
        guard let window = self.view.window else { return }
        self.isMasked = true
        let product = PurchaseManager.shared.paddleProduct
        let manager = PurchaseManager.shared
        let checkoutOptions = PADCheckoutOptions()
        #if DEBUG
        checkoutOptions.email = "82flex@gmail.com"
        checkoutOptions.country = "HK"
        checkoutOptions.coupon = "D3223D1F"
        #endif
        manager.paddle.showCheckout(
            for: product,
            options: checkoutOptions
        ) { [weak self] (state, data) in
            guard let self = self, let data = data else { return }
            do {
                switch state {
                    case .purchased:
                        debugPrint("Purchase Succeed: \(data.debugDescription)")
                        try manager.loadLocalReceipt { [weak self] (verificationState, error, details) in
                            guard let self = self else { return }
                            do {
                                switch verificationState {
                                    case .verified:
                                        // TODO: checkout succeed
                                        DispatchQueue.main.async {
                                            self.isMasked = false
                                        }
                                        fatalError("not implemented: checkout succeed, validate license")
                                    case .noActivation:
                                        throw Error.validateNoActivation
                                    case .unableToVerify:
                                        throw Error.validateUnableToVerify
                                    case .unverified:
                                        throw Error.unverified
                                    @unknown default:
                                        fatalError()
                                }
                            } catch let error {
                                DispatchQueue.main.async {
                                    let alert = NSAlert(error: error)
                                    alert.beginSheetModal(for: window) { _ in
                                        self.isMasked = false
                                    }
                                }
                            }
                        }
                    case .failed:
                        throw Error.checkoutFailed
                    case .flagged:
                        throw Error.checkoutFlagged
                    case .slowOrderProcessing:
                        throw Error.checkoutSlowOrderProcessing
                    case .abandoned:
                        // payment cancelled
                        DispatchQueue.main.async {
                            self.isMasked = false
                        }
                    @unknown default:
                        // unknown
                        DispatchQueue.main.async {
                            self.isMasked = false
                        }
                }
            } catch {
                DispatchQueue.main.async {
                    let alert = NSAlert(error: error)
                    alert.beginSheetModal(for: window) { _ in
                        self.isMasked = false
                    }
                }
            }
        }
    }
    #endif
    
    #if APP_STORE
    private func restoreSubscription() {
        guard let window = self.view.window else { return }
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
                            let alert = NSAlert(error: error)
                            alert.beginSheetModal(for: window) { _ in
                                self.isMasked = false
                            }
                        }
                        return
                    }
                    DispatchQueue.main.async {
                        self.isMasked = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    let alert = NSAlert(error: error)
                    alert.beginSheetModal(for: window) { _ in
                        self.isMasked = false
                    }
                }
            }
        }
    }
    #else
    private func restoreSubscription() {
        guard let window = self.view.window else { return }
        self.isMasked = true
        if let promptWindowController = NSStoryboard(name: "Purchase", bundle: nil).instantiateController(withIdentifier: PaddleLicenseActivationViewController.windowStoryboardIdentifier) as? PaddleLicenseActivationWindowController,
            let promptWindow = promptWindowController.window
        {
            let product = PurchaseManager.shared.paddleProduct
            window.beginSheet(promptWindow) { [unowned self] resp in
                if resp == .cancel {
                    self.isMasked = false
                }
                else if resp == .continue {
                    let alert = NSAlert(
                        style: .informational,
                        text: .init(
                            message: NSLocalizedString("Recover your JSTColorPicker license", comment: "restoreSubscription()"),
                            information: NSLocalizedString("Enter your email address to receive the lost license code.", comment: "restoreSubscription()")
                        ),
                        textField: .init(text: "", placeholder: NSLocalizedString("Your Email Address", comment: "restoreSubscription()")),
                        button: .init(title: NSLocalizedString("Continue", comment: "restoreSubscription()"))
                    )
                    alert.beginSheetModal(for: window) { [unowned self] resp in
                        if resp == .alertFirstButtonReturn,
                           let emailAddress = alert.textField?.stringValue,
                           !emailAddress.isEmpty
                        {
                            PurchaseManager.shared.paddle.recoverLicense(
                                for: product,
                                email: emailAddress
                            ) { [unowned self] recovered, error in
                                if let error = error {
                                    let alert = NSAlert(error: error)
                                    alert.beginSheetModal(for: window) { [unowned self] alertResp in
                                        self.isMasked = false
                                    }
                                    return
                                } else if recovered {
                                    let anotherAlert = NSAlert(style: .informational, text: .init(message: NSLocalizedString("Recovery instructions have been sent to your email address if it was registered in our database.", comment: "restoreSubscription()"), information: ""))
                                    anotherAlert.beginSheetModal(for: window) { _ in
                                        self.isMasked = false
                                    }
                                } else {
                                    // nothing happened...
                                    self.isMasked = false
                                }
                            }
                        } else {
                            self.isMasked = false
                        }
                    }
                }
                else {
                    product.activateEmail(
                        promptWindowController.emailAddress,
                        license: promptWindowController.licenseCode
                    ) { [unowned self] activated, error in
                        if let error = error {
                            let alert = NSAlert(error: error)
                            alert.beginSheetModal(for: window) { [unowned self] alertResp in
                                self.isMasked = false
                            }
                            return
                        } else if activated {
                            // TODO: validate license
                            fatalError("not implemented: restore succeed, validate license")
                        }
                    }
                }
            }
        }
    }
    #endif
    
    #if APP_STORE
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
                    try PurchaseManager.shared.verifySubscriptionState(purchaseResult)
                    completion(true, nil)
                case .error(let error):
                    throw error
                }
            } catch {
                completion(false, error)
            }
        }
    }
    #endif
    
    #if APP_STORE
    private func fetchExistingReceipt(forceRefresh force: Bool) {
        guard let window = self.view.window else { return }
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
                    let alert = NSAlert(error: error)
                    alert.beginSheetModal(for: window) { _ in
                        self.isMasked = false
                    }
                }
            }
        }
    }
    #endif
    
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
    
    @IBAction private func checkUpdatesButtonTapped(_ sender: NSButton) {
        AppDelegate.shared.sparkUpdater.checkForUpdates(sender)
    }
    
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
