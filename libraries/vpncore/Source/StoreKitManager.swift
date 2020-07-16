//
//  StoreKitManager.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Reachability
import StoreKit

public protocol StoreKitManagerFactory {
    func makeStoreKitManager() -> StoreKitManager
}

public protocol StoreKitManager: NSObjectProtocol {

    typealias SuccessCallback = (PaymentToken?) -> Void
    
    func subscribeToPaymentQueue()
    func purchaseProduct(withId id: String, refreshHandler: @escaping () -> Void, successCompletion: @escaping SuccessCallback, errorCompletion: @escaping (Error) -> Void, deferredCompletion: @escaping () -> Void)
    func processAllTransactions()
    func processAllTransactions(_ finishHandler: (() -> Void)?)
    func updateAvailableProductsList()
    func readyToPurchaseProduct() -> Bool
    func currentTransaction() -> SKPaymentTransaction?
    func priceLabelForProduct(id: String) -> (NSDecimalNumber, Locale)?
}

public class StoreKitManagerImplementation: NSObject, StoreKitManager {
   
    public typealias Factory = CoreAlertServiceFactory & PaymentsApiServiceFactory & ServicePlanDataStorageFactory & PaymentTokenStorageFactory
    private let factory: Factory
        
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var paymentsService: PaymentsApiService = factory.makePaymentsApiService()
    private lazy var servicePlanDataStorage: ServicePlanDataStorage = factory.makeServicePlanDataStorage()
    private lazy var tokenStorage: PaymentTokenStorage = factory.makePaymentTokenStorage()
        
    public init(factory: Factory) {
        self.factory = factory
        super.init()
        
        try? reachability?.startNotifier()
        reachability?.whenReachable = { [weak self] _ in self?.networkReachable() }
    }
    
    deinit {
        reachability?.stopNotifier()
    }
    
    private let reachability = Reachability()
    
    private var productIds = Set([AccountPlan.basic.storeKitProductId!, AccountPlan.plus.storeKitProductId!])
    private var availableProducts: [SKProduct] = []
    private var request: SKProductsRequest!
    private var transactionsQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = QualityOfService.userInteractive
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private var transactionsMadeBeforeSignup = [SKPaymentTransaction]()
    private var transactionsFinishHandler: (() -> Void)?
        
    internal var refreshHandler: (() -> Void)? // allow hook for ui updates
    private var successCompletion: StoreKitManager.SuccessCallback?
    private var deferredCompletion: (() -> Void)?
    private lazy var errorCompletion: (Error) -> Void = { error in
        PMLog.ET("StoreKit error: \(error.localizedDescription)")
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) { [weak self] in
            self?.alertService.push(alert: StoreKitErrorAlert(withMessage: error.localizedDescription))
            
        }
    }
    
    private lazy var confirmUserValidationBypass: (Error, @escaping () -> Void) -> Void = { error, completion in
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [weak self] in
            guard let currentUsername = AuthKeychain.fetch()?.username else {
                self?.errorCompletion(Errors.noActiveUsername)
                return
            }
            
            let message = """
            \(error.localizedDescription)
            \(String(format: LocalizedString.doYouWantToActivateSubscriptionFor, currentUsername))
            """
            
            self?.alertService.push(alert: StoreKitUserValidationByPassAlert(withMessage: message, confirmHandler: {
                completion()
            }))
        }
    }
    
    public func subscribeToPaymentQueue() {
        SKPaymentQueue.default().add(self)
    }
    
    public func updateAvailableProductsList() {
        request = SKProductsRequest(productIdentifiers: self.productIds)
        request.delegate = self
        request.start()
    }
    
    public func priceLabelForProduct(id: String) -> (NSDecimalNumber, Locale)? {
        guard let product = self.availableProducts.first(where: { $0.productIdentifier == id }) else {
            return nil
        }
        return (product.price, product.priceLocale)
    }
    
    public func readyToPurchaseProduct() -> Bool {
        // no matter which user is logged in now, if there is any unfinished transaction - we do not want to give opportunity to start new purchase. BE currently can process only last transaction in Receipts, so we do not want to mess up the older ones.
        return SKPaymentQueue.default().transactions.filter { $0.transactionState != .failed }.isEmpty
    }
    
    public func currentTransaction() -> SKPaymentTransaction? {
        return SKPaymentQueue.default().transactions.filter { $0.transactionState != .failed }.first
    }
    
    public func purchaseProduct(withId id: String,
                                refreshHandler: @escaping () -> Void,
                                successCompletion: @escaping StoreKitManager.SuccessCallback,
                                errorCompletion: @escaping (Error) -> Void,
                                deferredCompletion: @escaping () -> Void) {

        guard let product = self.availableProducts.first(where: { $0.productIdentifier == id }) else {
            errorCompletion(Errors.unavailableProduct)
            return
        }
        
        self.refreshHandler = refreshHandler
        self.successCompletion = successCompletion
        self.errorCompletion = errorCompletion
        self.deferredCompletion = deferredCompletion
        
        let payment = SKMutablePayment(product: product)
        payment.quantity = 1
        if let userId = self.applicationUserId() {
            payment.applicationUsername = self.hash(userId: userId)
        }
        
        SKPaymentQueue.default().add(payment)
        PMLog.D("StoreKit: Purchase started")
    }
    
    private func networkReachable() {
        processAllTransactions()
    }
    
    public enum Errors: LocalizedError {
        case unavailableProduct
        case receiptLost
        case haveTransactionOfAnotherUser
        case alreadyPurchasedPlanDoesNotMatchBackend
        case sandboxReceipt
        case creditsApplied
        case transactionFailedByUnknownReason
        case noActiveUsername
        case noNewSubscriptionInSuccessfullResponse
        
        public var errorDescription: String? {
            switch self {
            case .unavailableProduct: return LocalizedString.errorUnavailableProduct
            case .receiptLost: return LocalizedString.errorReceiptLost
            case .haveTransactionOfAnotherUser: return LocalizedString.errorTransactionOfOtherUser
            case .alreadyPurchasedPlanDoesNotMatchBackend: return LocalizedString.errorPurchasedPlanDoesNotMatchAvailable
            case .sandboxReceipt: return LocalizedString.errorSandboxReceipt
            case .creditsApplied: return LocalizedString.errorCreditsApplied
            case .transactionFailedByUnknownReason: return LocalizedString.errorTransactionFailedByUnknownReason
            case .noActiveUsername: return LocalizedString.errorNoActiveUsername
            case .noNewSubscriptionInSuccessfullResponse: return LocalizedString.errorNoNewSubscriptionInSuccessfullResponse
            }
        }
    }
}

extension StoreKitManagerImplementation: SKProductsRequestDelegate {
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        self.availableProducts = response.products
    }
    
    private func hash(userId: String) -> String {
        return userId.sha256
    }
    
    private func applicationUserId() -> String? {
        guard let userId = AuthKeychain.fetch()?.userId, !userId.isEmpty else {
            return nil
        }
        return userId
    }
}

extension StoreKitManagerImplementation: SKPaymentTransactionObserver {
    // this will be called right after the purchase and after relaunch
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        self.processAllTransactions()
    }
    
    // this will be called after relogin and from the method above
    public func processAllTransactions(_ finishHandler: (() -> Void)? = nil) {
        self.transactionsQueue.cancelAllOperations()
        
        guard !SKPaymentQueue.default().transactions.isEmpty else {
            finishHandler?()
            return
        }
        
        PMLog.D("StoreKit transaction queue contains transaction(s). Will handle it now.")
        transactionsFinishHandler = finishHandler
        SKPaymentQueue.default().transactions.forEach { transaction in
            self.addOperation { self.process(transaction) }
        }
    }
    
    public func processAllTransactions() {
        processAllTransactions(transactionsFinishHandler)
    }
    
    /// Adds operation to queue plus adds additional operation that check if queue is empty and calls finish handler if available
    private func addOperation(block: @escaping () -> Void) {
        let mainOperation = BlockOperation(block: block)
        let finishOperation = BlockOperation(block: { [weak self] in
            self?.handleQueueFinish()
        })
        finishOperation.addDependency(mainOperation)
        finishOperation.name = "Finish check"
        self.transactionsQueue.addOperation(mainOperation)
        self.transactionsQueue.addOperation(finishOperation)
    }
    
    private func handleQueueFinish() {
        guard transactionsQueue.operationCount <= 1 else { // The last operation in queue is check for finished queue execution
            return
        }
        transactionsFinishHandler?()
        transactionsFinishHandler = nil
    }
    
    private func process(_ transaction: SKPaymentTransaction, shouldVerifyPurchaseWasForSameAccount shouldVerify: Bool = true) {
        switch transaction.transactionState {
        case .failed:
            proceed(withFailed: transaction)
        case .purchased:
            do {
                try self.proceed(withPurchased: transaction, shouldVerifyPurchaseWasForSameAccount: shouldVerify)
            } catch Errors.haveTransactionOfAnotherUser { // user login error
                confirmUserValidationBypass(Errors.haveTransactionOfAnotherUser) {
                    self.addOperation { self.process(transaction, shouldVerifyPurchaseWasForSameAccount: false) }
                }
            } catch Errors.sandboxReceipt {  // receipt error
                self.errorCompletion(Errors.sandboxReceipt)
                SKPaymentQueue.default().finishTransaction(transaction)
                
            } catch Errors.receiptLost { // receipt error
                self.errorCompletion(Errors.receiptLost)
                SKPaymentQueue.default().finishTransaction(transaction)
                
            } catch Errors.noNewSubscriptionInSuccessfullResponse { // error on BE
                self.errorCompletion(Errors.noNewSubscriptionInSuccessfullResponse)
                SKPaymentQueue.default().finishTransaction(transaction)
                
            } catch let error { // other errors
                self.errorCompletion(error)
            }
        case .deferred, .purchasing:
            self.deferredCompletion?()
            
        case .restored:
            break // never happens in our flow
        }
    }
    
    private func proceed(withFailed transaction: SKPaymentTransaction) {
        SKPaymentQueue.default().finishTransaction(transaction)
        let error = transaction.error as NSError?
        switch error {
        case .some(SKError.paymentCancelled):
            break
        case .some(let error):
            self.errorCompletion(error)
        case .none:
            self.errorCompletion(Errors.transactionFailedByUnknownReason)
        }
        
        refreshHandler?()
    }
    
    private func proceed(withPurchased transaction: SKPaymentTransaction,
                         shouldVerifyPurchaseWasForSameAccount: Bool = true) throws {
        
        if shouldVerifyPurchaseWasForSameAccount, let transactionHashedUserId = transaction.payment.applicationUsername {
            try self.verifyCurrentCredentialsMatch(usernameFromTransaction: transactionHashedUserId)
        }
        
        guard let plan = AccountPlan(storeKitProductId: transaction.payment.productIdentifier),
            let details = plan.fetchDetails(),
            let planId = details.iD else {
            self.errorCompletion(Errors.alreadyPurchasedPlanDoesNotMatchBackend)
            return
        }
        
        switch processingType {
        case .existingUserNewSubscription:
            if transactionsMadeBeforeSignup.contains(transaction) {
                processAuthenticatedBeforeSignup(transaction: transaction, plan: plan)
            } else {
                try processAuthenticated(transaction: transaction, plan: plan, planId: planId)
            }
        case .existingUserAddCredits:
            try processAuthenticatedAddCredits(transaction: transaction, plan: plan)
        case .registration:
            try processUnauthenticated(transaction: transaction, plan: plan)
        }
        
    }
    
    private func processAuthenticated(transaction: SKPaymentTransaction, plan: AccountPlan, planId: String) throws {
        let receipt = try self.readReceipt()
                
        // Ask user if she wants to retry or fill a bug report
        let retryOnError: (Error) -> Void = { [weak self] error in
            self?.alertService.push(alert: ApplyCreditAfterRegistrationFailedAlert(type: .upgrade,
                retryHandler: {
                    try? self?.processAuthenticated(transaction: transaction, plan: plan, planId: planId) // Exception would've been thrown on the first call
                },
                supportHandler: {
//                    self?.finish(transaction: transaction)
                    SKPaymentQueue.default().finishTransaction(transaction)
                    self?.errorCompletion(error)
                    self?.alertService.push(alert: ReportBugAlert())
                })
            )
        }
        
        // 1. Create token
        guard let token = tokenStorage.get() else {
            PMLog.ET("StoreKit: No proton token found")
            paymentsService.createPaymentToken(amount: plan.yearlyCost, receipt: receipt, success: { [weak self] token in
                self?.tokenStorage.add(token)
                try? self?.processAuthenticated(transaction: transaction, plan: plan, planId: planId) // Exception would've been thrown on the first call
                
            }, failure: { [weak self] error in
                PMLog.D("StoreKit: payment token was not created")
                switch (error as NSError).code {
                case 22914: // sandbox receipt sent to BE
                    SKPaymentQueue.default().finishTransaction(transaction)
                    self?.errorCompletion(error)
                case 22916: // Apple payment already registered
                    PMLog.D("StoreKit: apple payment already registered (2)")
                    SKPaymentQueue.default().finishTransaction(transaction)
                    self?.successCompletion?(nil)
                default:
                    self?.errorCompletion(error)
                }
            })
            return
        }
        
        paymentsService.getPaymentTokenStatus(token: token, success: { [weak self] tokenStatus in
            switch tokenStatus.status {
            case .pending: // Waiting for the token to get ready to be charged (should not happen with IAP)
                let retryIn: Double = 30
                PMLog.D("StoreKit: token not ready yet. Scheduling retry in \(retryIn) seconds")
                DispatchQueue.main.asyncAfter(deadline: .now() + retryIn) {
                    try? self?.processAuthenticated(transaction: transaction, plan: plan, planId: planId) // Exception would've been thrown on the first call
                }
                return
                
            case .chargeable: // Gr8 success
                self?.paymentsService.buyPlan(id: planId, price: plan.yearlyCost, paymentToken: .protonToken(token: token.token), success: { [weak self] subscription in
                    PMLog.D("StoreKit: success (1)")
                    ServicePlanDataServiceImplementation.shared.currentSubscription = subscription
                    SKPaymentQueue.default().finishTransaction(transaction)
                    self?.tokenStorage.clear()
                    self?.successCompletion?(nil)
                    
                }, failure: { error in
                    PMLog.ET("StoreKit: Buy plan failed: \(error.localizedDescription)")
                    
                    // MORE here
                    
                    retryOnError(error)
                    
                    
                    guard let `self` = self else { return }
                    switch (error as NSError).code {
                    case 22101:
                        PMLog.D("StoreKit: amount mismatch")
                        // ammount mismatch - try report only credits without activating the plan
                        self.paymentsService.credit(amount: plan.yearlyCost, receipt: .protonToken(token: token.token), success: {
                            self.errorCompletion(Errors.creditsApplied)
                            SKPaymentQueue.default().finishTransaction(transaction)
                        }, failure: { (error) in
                            if (error as NSError).code == 22916 { // Apple payment already registered
                                PMLog.D("StoreKit: apple payment already registered")
                                SKPaymentQueue.default().finishTransaction(transaction)
                            } else {
                                self.errorCompletion(error)
                            }
                        })
                    default:
                        self.errorCompletion(error)
                    }
                    
                    
                })
                
            case .failed: // throw away token and retry with the new one
                PMLog.D("StoreKit: token failed")
                self?.tokenStorage.clear()
                try? self?.processAuthenticated(transaction: transaction, plan: plan, planId: planId) // Exception would've been thrown on the first call
                
            case .consumed: // throw away token and receipt
                PMLog.D("StoreKit: token already consumed")
                SKPaymentQueue.default().finishTransaction(transaction)
                self?.tokenStorage.clear()
                self?.successCompletion?(nil)
                
            case .notSupported: // throw away token and retry
                self?.tokenStorage.clear()
                try? self?.processAuthenticated(transaction: transaction, plan: plan, planId: planId) // Exception would've been thrown on the first call
            }
                        
        }, failure: { error in
            PMLog.ET("StoreKit: Get token info failed: \(error.localizedDescription)")
            self.errorCompletion(error)
        })
        
        
               
        
        /**** */
        
        // payments/subscription
        paymentsService.postReceipt(amount: plan.yearlyCost, receipt: receipt, planId: planId, success: { [weak self] subscription in
            PMLog.D("StoreKit: success (1)")
            ServicePlanDataServiceImplementation.shared.currentSubscription = subscription
            self?.successCompletion?(nil)
            SKPaymentQueue.default().finishTransaction(transaction)
        }, failure: { [weak self] (error) in
            guard let `self` = self else { return }
            switch (error as NSError).code {
            case 22101:
                PMLog.D("StoreKit: amount mismatch")
                // ammount mismatch - try report only credits without activating the plan
                self.paymentsService.credit(amount: plan.yearlyCost, receipt: .apple(token: receipt), success: {
                    self.errorCompletion(Errors.creditsApplied)
                    SKPaymentQueue.default().finishTransaction(transaction)
                }, failure: { (error) in
                    if (error as NSError).code == 22916 { // Apple payment already registered
                        PMLog.D("StoreKit: apple payment already registered")
                        SKPaymentQueue.default().finishTransaction(transaction)
                    } else {
                        self.errorCompletion(error)
                    }
                })
            case 22914: // sandbox receipt sent to BE
                SKPaymentQueue.default().finishTransaction(transaction)
                self.errorCompletion(error)
            case 22916: // Apple payment already registered
                PMLog.D("StoreKit: apple payment already registered (2)")
                SKPaymentQueue.default().finishTransaction(transaction)
            default:
                self.errorCompletion(error)
            }
        })
        /*  END of code for deletion  */
    }
    
    // swiftlint:disable function_body_length
    private func processAuthenticatedBeforeSignup(transaction: SKPaymentTransaction, plan: AccountPlan) {
        guard let details = plan.fetchDetails(), let planId = details.iD else {
            PMLog.ET("StoreKit: Can't fetch plan details")
            return
        }
                
        // Ask user if he wants to retry or fill a bug report
        let retryOnError = { [weak self] in
            self?.alertService.push(alert: ApplyCreditAfterRegistrationFailedAlert(type: .registration,
                retryHandler: {
                    self?.processAuthenticatedBeforeSignup(transaction: transaction, plan: plan)
                },
                supportHandler: {
                    self?.finish(transaction: transaction)
                    self?.alertService.push(alert: ReportBugAlert())
                })
            )
        }
        
        guard let token = tokenStorage.get() else {
            // Try to recover by recreating the token from our receipt
            guard let receipt = try? self.readReceipt() else {
                PMLog.ET("StoreKit: Proton token not found! Apple receipt not found!")
                return
            }
            PMLog.D("StoreKit: No proton token found")
            paymentsService.createPaymentToken(amount: plan.yearlyCost, receipt: receipt, success: { [weak self] token in
                PMLog.D("StoreKit: payment token (re)created")
                self?.tokenStorage.add(token)
                self?.processAuthenticatedBeforeSignup(transaction: transaction, plan: plan)
                
            }, failure: { error in
                PMLog.D("StoreKit: payment token was not (re)created")
                retryOnError()
            })
            return
        }
        
        paymentsService.getPaymentTokenStatus(token: token, success: { [weak self] tokenStatus in
            
            switch tokenStatus.status {
            case .pending: // Waiting for the token to get ready to be charged (should not happen with IAP)
                let retryIn: Double = 30
                PMLog.D("StoreKit: token not ready yet. Scheduling retry in \(retryIn) seconds")
                DispatchQueue.main.asyncAfter(deadline: .now() + retryIn) {
                    self?.processAuthenticatedBeforeSignup(transaction: transaction, plan: plan)
                }
                return
                
            case .chargeable: // Gr8 success
                self?.paymentsService.buyPlan(id: planId, price: plan.yearlyCost, paymentToken: .protonToken(token: token.token), success: { [weak self] subscription in
                    PMLog.D("StoreKit: success (2)")
                    self?.finish(transaction: transaction)
                    self?.tokenStorage.clear()
                    
                }, failure: { error in
                    PMLog.ET("StoreKit: Buy plan failed: \(error.localizedDescription)")
                    retryOnError()
                })
                
            case .failed: // throw away token and retry with the new one
                PMLog.D("StoreKit: token failed")
                self?.tokenStorage.clear()
                self?.processAuthenticatedBeforeSignup(transaction: transaction, plan: plan)
                
            case .consumed: // throw away token and receipt
                PMLog.D("StoreKit: token already consumed")
                self?.finish(transaction: transaction)
                self?.tokenStorage.clear()
                
            case .notSupported: // throw away token and retry
                self?.tokenStorage.clear()
                retryOnError()
            }
                        
        }, failure: { error in
            PMLog.ET("StoreKit: Get token info failed: \(error.localizedDescription)")
            
            if error.isTlsError || error.isNetworkError {
                retryOnError()
                return
            }

            let retryIn: Double = 10
            PMLog.D("StoreKit: will cleanup old token and restart procedure in \(retryIn) seconds")
            self.tokenStorage.clear()
            DispatchQueue.main.asyncAfter(deadline: .now() + retryIn) {
                self.processAuthenticatedBeforeSignup(transaction: transaction, plan: plan)
            }
        })
        
    }
    // swiftlint:enable function_body_length
    
    /// Add credits to user account 
    private func processAuthenticatedAddCredits(transaction: SKPaymentTransaction, plan: AccountPlan) throws {
        let receipt = try self.readReceipt()
        paymentsService.createPaymentToken(amount: plan.yearlyCost, receipt: receipt, success: { [weak self] token in
            self?.paymentsService.credit(amount: plan.yearlyCost, receipt: .protonToken(token: token.token), success: {
                PMLog.D("StoreKit: credits added")
                self?.successCompletion?(nil)
                SKPaymentQueue.default().finishTransaction(transaction)
            }, failure: { (error) in
                if (error as NSError).code == 22916 { // Apple payment already registered
                    PMLog.D("StoreKit: apple payment already registered (3)")
                    SKPaymentQueue.default().finishTransaction(transaction)
                } else {
                    self?.errorCompletion(error)
                }
            })
        }, failure: { [weak self] error in
            self?.errorCompletion(error)
        })
    }
    
    private func finish(transaction: SKPaymentTransaction) {
        SKPaymentQueue.default().finishTransaction(transaction)
        transactionsMadeBeforeSignup.removeAll(where: { $0 == transaction })
    }
    
    private func processUnauthenticated(transaction: SKPaymentTransaction, plan: AccountPlan) throws {
        let receipt = try self.readReceipt()
                
        paymentsService.createPaymentToken(amount: plan.yearlyCost, receipt: receipt, success: { [weak self] token in
            PMLog.D("StoreKit: payment token created for signup")
            self?.tokenStorage.add(token)
            self?.successCompletion?(token)
            self?.transactionsMadeBeforeSignup.append(transaction)
            // Transaction will be finished after login
            
        }, failure: { [weak self] error in
            self?.errorCompletion(error)
        })
                
    }
    
    var processingType: ProcessingType {
        if let userId = AuthKeychain.fetch()?.userId, !userId.isEmpty {
            if servicePlanDataStorage.currentSubscription?.endDate?.isFuture ?? false {
                return .existingUserAddCredits
            }
            return .existingUserNewSubscription
        }
        return .registration
    }
    
    enum ProcessingType {
        case existingUserNewSubscription
        case existingUserAddCredits
        case registration
    }
}

extension StoreKitManagerImplementation {
    
    private func verifyCurrentCredentialsMatch(usernameFromTransaction hashedTransactionUserId: String) throws {
        guard let currentUserId = self.applicationUserId() else {
            throw Errors.noActiveUsername
        }
        guard hashedTransactionUserId == self.hash(userId: currentUserId) else {
            throw Errors.haveTransactionOfAnotherUser
        }
    }
    
    func readReceipt() throws -> String {
        guard let receiptUrl = Bundle.main.appStoreReceiptURL else {
            throw Errors.sandboxReceipt
        }
        guard !receiptUrl.lastPathComponent.contains("sandbox") || ApiConstants.baseURL != ApiConstants.liveURL else { // don't allow sandbox receipts on live
            throw Errors.sandboxReceipt
        }

        PMLog.D(receiptUrl.path) // make use of the receipt url so maybe compiler will not screw it up while optimising
        guard let receipt = try? Data(contentsOf: receiptUrl).base64EncodedString() else {
            throw Errors.receiptLost
        }
        
        return receipt
    }
}
