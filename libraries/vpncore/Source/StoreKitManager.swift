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

// FUTUREDO: Refactor this whole thing
public protocol StoreKitManager: NSObjectProtocol {

    typealias SuccessCallback = (PaymentToken?) -> Void
    
    func subscribeToPaymentQueue()
    func purchaseProduct(withId id: String, successCompletion: @escaping SuccessCallback, errorCompletion: @escaping (Error) -> Void, deferredCompletion: @escaping () -> Void)
    func processAllTransactions()
    func processAllTransactions(_ finishHandler: (() -> Void)?)
    func updateAvailableProductsList()
    func readyToPurchaseProduct() -> Bool
    func currentTransaction() -> SKPaymentTransaction?
    func priceLabelForProduct(id: String) -> (NSDecimalNumber, Locale)?
}

public class StoreKitManagerImplementation: NSObject, StoreKitManager {
    
    public static var transactionFinishedNotification = Notification.Name("StoreKitManager.transactionFinished")
   
    public typealias Factory = CoreAlertServiceFactory & PaymentsApiServiceFactory & ServicePlanDataStorageFactory & PaymentTokenStorageFactory
    private let factory: Factory
        
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var paymentsService: PaymentsApiService = factory.makePaymentsApiService()
    private lazy var servicePlanDataStorage: ServicePlanDataStorage = factory.makeServicePlanDataStorage()
    private lazy var tokenStorage: PaymentTokenStorage = factory.makePaymentTokenStorage()
        
    public init(factory: Factory) {
        self.factory = factory
        reachability = try? Reachability()
        super.init()
        
        try? reachability?.startNotifier()
        reachability?.whenReachable = { [weak self] _ in self?.networkReachable() }
    }
    
    deinit {
        reachability?.stopNotifier()
    }
    
    private let reachability: Reachability?
    
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
                                successCompletion: @escaping StoreKitManager.SuccessCallback,
                                errorCompletion: @escaping (Error) -> Void,
                                deferredCompletion: @escaping () -> Void) {

        guard let product = self.availableProducts.first(where: { $0.productIdentifier == id }) else {
            errorCompletion(Errors.unavailableProduct)
            return
        }
        
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
        case wrongTokenStatus(PaymentToken.Status)
        case cancelled
        
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
            case .wrongTokenStatus: return LocalizedString.errorWrongPaymentTokenStatus
            case .cancelled: return nil
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
            // Flatten async calls inside `proceed()`
            let group = DispatchGroup()
            group.enter()
            
            do {
                try self.proceed(withPurchased: transaction, shouldVerifyPurchaseWasForSameAccount: shouldVerify, completion: {
                    group.leave()
                })
                
            } catch Errors.haveTransactionOfAnotherUser { // user login error
                confirmUserValidationBypass(Errors.haveTransactionOfAnotherUser) {
                    self.addOperation { self.process(transaction, shouldVerifyPurchaseWasForSameAccount: false) }
                }
                group.leave()
            } catch Errors.sandboxReceipt {  // receipt error
                self.errorCompletion(Errors.sandboxReceipt)
                SKPaymentQueue.default().finishTransaction(transaction)
                group.leave()
                
            } catch Errors.receiptLost { // receipt error
                self.errorCompletion(Errors.receiptLost)
                SKPaymentQueue.default().finishTransaction(transaction)
                group.leave()
                
            } catch Errors.noNewSubscriptionInSuccessfullResponse { // error on BE
                self.errorCompletion(Errors.noNewSubscriptionInSuccessfullResponse)
                SKPaymentQueue.default().finishTransaction(transaction)
                group.leave()
                
            } catch let error { // other errors
                self.errorCompletion(error)
                group.leave()
            }
            
            group.wait()
            
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
            self.errorCompletion(Errors.cancelled)
        case .some(let error):
            self.errorCompletion(error)
        case .none:
            self.errorCompletion(Errors.transactionFailedByUnknownReason)
        }
    }
    
    private func proceed(withPurchased transaction: SKPaymentTransaction,
                         shouldVerifyPurchaseWasForSameAccount: Bool = true,
                         completion: @escaping () -> Void) throws {
        
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
                processAuthenticatedBeforeSignup(transaction: transaction, plan: plan, completion: completion)
            } else {
                try processAuthenticated(transaction: transaction, plan: plan, planId: planId, completion: completion)
            }
        case .existingUserAddCredits:
            try processAuthenticatedAddCredits(transaction: transaction, plan: plan, completion: completion)
        case .registration:
            try processUnauthenticated(transaction: transaction, plan: plan, completion: completion)
        }
        
    }
    
    // swiftlint:disable cyclomatic_complexity function_body_length
    private func processAuthenticated(transaction: SKPaymentTransaction, plan: AccountPlan, planId: String, completion: @escaping () -> Void) throws {
        let receipt = try self.readReceipt()
        
        // Create token
        guard let token = tokenStorage.get() else {
            PMLog.ET("StoreKit: No proton token found")
            paymentsService.createPaymentToken(amount: plan.yearlyCost, receipt: receipt, success: { [weak self] token in
                self?.tokenStorage.add(token)
                try? self?.processAuthenticated(transaction: transaction, plan: plan, planId: planId, completion: completion) // Exception would've been thrown on the first call
                
            }, failure: { [weak self] error in
                PMLog.D("StoreKit: payment token was not created")
                switch (error as NSError).code {
                case 22914: // sandbox receipt sent to BE
                    SKPaymentQueue.default().finishTransaction(transaction)
                    self?.tokenStorage.clear()
                    self?.errorCompletion(error)
                case 22916: // Apple payment already registered
                    PMLog.D("StoreKit: apple payment already registered (2)")
                    SKPaymentQueue.default().finishTransaction(transaction)
                    self?.tokenStorage.clear()
                    self?.successCompletion?(nil)
                default:
                    self?.errorCompletion(error)
                }
                completion()
            })
            return
        }
        
        // FUTUREDO: start using coroutines or something similar
        
        paymentsService.getPaymentTokenStatus(token: token, success: { [weak self] tokenStatus in
            switch tokenStatus.status {
            case .pending: // Waiting for the token to get ready to be charged (should not happen with IAP)
                let retryIn: Double = 30
                PMLog.D("StoreKit: token not ready yet. Scheduling retry in \(retryIn) seconds")
                DispatchQueue.main.asyncAfter(deadline: .now() + retryIn) {
                    try? self?.processAuthenticated(transaction: transaction, plan: plan, planId: planId, completion: completion) // Exception would've been thrown on the first call
                }
                return
                
            case .chargeable: // Gr8 success
                self?.paymentsService.buyPlan(id: planId, price: plan.yearlyCost, paymentToken: .protonToken(token: token.token), success: { [weak self] subscription in
                    PMLog.D("StoreKit: success (1)")
                    ServicePlanDataServiceImplementation.shared.currentSubscription = subscription
                    SKPaymentQueue.default().finishTransaction(transaction)
                    self?.tokenStorage.clear()
                    self?.successCompletion?(nil)
                    completion()
                    
                }, failure: { error in
                    PMLog.ET("StoreKit: Buy plan failed: \(error.localizedDescription)")
                                        
                    guard let `self` = self else { return }
                    switch (error as NSError).code {
                    case 22101: // ammount mismatch
                        PMLog.D("StoreKit: amount mismatch")
                        // ammount mismatch - try report only credits without activating the plan
                        self.paymentsService.credit(amount: plan.yearlyCost, receipt: .protonToken(token: token.token), success: {
                            SKPaymentQueue.default().finishTransaction(transaction)
                            self.tokenStorage.clear()
                            self.errorCompletion(Errors.creditsApplied)
                            completion()
                        }, failure: { [weak self] (error) in
                            if (error as NSError).code == 22916 { // Apple payment already registered
                                PMLog.D("StoreKit: apple payment already registered")
                                SKPaymentQueue.default().finishTransaction(transaction)
                                self?.tokenStorage.clear()
                                self?.successCompletion?(nil)
                            } else {
                                self?.errorCompletion(error)
                            }
                            completion()
                        })
                    default:
                        self.errorCompletion(error)
                        completion()
                    }
                    
                })
                
            case .failed: // throw away token and retry with the new one
                PMLog.D("StoreKit: token failed")
                self?.tokenStorage.clear()
                self?.errorCompletion(Errors.wrongTokenStatus(tokenStatus.status))
                completion()
                
            case .consumed: // throw away token and receipt
                PMLog.D("StoreKit: token already consumed")
                SKPaymentQueue.default().finishTransaction(transaction)
                self?.tokenStorage.clear()
                self?.successCompletion?(nil)
                completion()
                
            case .notSupported: // throw away token and retry
                PMLog.D("StoreKit: token not supported")
                self?.tokenStorage.clear()
                self?.errorCompletion(Errors.wrongTokenStatus(tokenStatus.status))
                completion()
            }
                        
        }, failure: { error in
            PMLog.ET("StoreKit: Get token info failed: \(error.localizedDescription)")
            self.errorCompletion(error)
            completion()
        })
    }
    // swiftlint:enable cyclomatic_complexity function_body_length
    
    // swiftlint:disable function_body_length
    private func processAuthenticatedBeforeSignup(transaction: SKPaymentTransaction, plan: AccountPlan, completion: @escaping () -> Void) {
        guard let details = plan.fetchDetails(), let planId = details.iD else {
            PMLog.ET("StoreKit: Can't fetch plan details")
            completion()
            return
        }
                
        // Ask user if he wants to retry or fill a bug report
        let retryOnError = { [weak self] in
            self?.alertService.push(alert: ApplyCreditAfterRegistrationFailedAlert(type: .registration,
                retryHandler: {
                    self?.processAuthenticatedBeforeSignup(transaction: transaction, plan: plan, completion: completion)
                },
                supportHandler: {
                    self?.finish(transaction: transaction)
                    self?.alertService.push(alert: ReportBugAlert())
                    completion()
                })
            )
        }
        
        guard let token = tokenStorage.get() else {
            // Try to recover by recreating the token from our receipt
            guard let receipt = try? self.readReceipt() else {
                PMLog.ET("StoreKit: Proton token not found! Apple receipt not found!")
                completion()
                return
            }
            PMLog.D("StoreKit: No proton token found")
            paymentsService.createPaymentToken(amount: plan.yearlyCost, receipt: receipt, success: { [weak self] token in
                PMLog.D("StoreKit: payment token (re)created")
                self?.tokenStorage.add(token)
                self?.processAuthenticatedBeforeSignup(transaction: transaction, plan: plan, completion: completion)
                
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
                    self?.processAuthenticatedBeforeSignup(transaction: transaction, plan: plan, completion: completion)
                }
                return
                
            case .chargeable: // Gr8 success
                self?.paymentsService.buyPlan(id: planId, price: plan.yearlyCost, paymentToken: .protonToken(token: token.token), success: { [weak self] subscription in
                    PMLog.D("StoreKit: success (2)")
                    self?.finish(transaction: transaction)
                    self?.tokenStorage.clear()
                    completion()
                    
                }, failure: { error in
                    PMLog.ET("StoreKit: Buy plan failed: \(error.localizedDescription)")
                    retryOnError()
                })
                
            case .failed: // throw away token and retry with the new one
                PMLog.D("StoreKit: token failed")
                self?.tokenStorage.clear()
                self?.processAuthenticatedBeforeSignup(transaction: transaction, plan: plan, completion: completion)
                
            case .consumed: // throw away token and receipt
                PMLog.D("StoreKit: token already consumed")
                self?.finish(transaction: transaction)
                self?.tokenStorage.clear()
                completion()
                
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
                self.processAuthenticatedBeforeSignup(transaction: transaction, plan: plan, completion: completion)
            }
        })
        
    }
    // swiftlint:enable function_body_length
    
    /// Add credits to user account 
    private func processAuthenticatedAddCredits(transaction: SKPaymentTransaction, plan: AccountPlan, completion: @escaping () -> Void) throws {
        let receipt = try self.readReceipt()
        paymentsService.createPaymentToken(amount: plan.yearlyCost, receipt: receipt, success: { [weak self] token in
            self?.paymentsService.credit(amount: plan.yearlyCost, receipt: .protonToken(token: token.token), success: {
                PMLog.D("StoreKit: credits added")
                self?.successCompletion?(nil)
                SKPaymentQueue.default().finishTransaction(transaction)
                completion()
                
            }, failure: { (error) in
                if (error as NSError).code == 22916 { // Apple payment already registered
                    PMLog.D("StoreKit: apple payment already registered (3)")
                    SKPaymentQueue.default().finishTransaction(transaction)
                } else {
                    self?.errorCompletion(error)
                }
                completion()
            })
        }, failure: { [weak self] error in
            self?.errorCompletion(error)
            completion()
        })
    }
    
    private func finish(transaction: SKPaymentTransaction) {
        SKPaymentQueue.default().finishTransaction(transaction)
        transactionsMadeBeforeSignup.removeAll(where: { $0 == transaction })
        NotificationCenter.default.post(name: StoreKitManagerImplementation.transactionFinishedNotification, object: nil)
    }
    
    private func processUnauthenticated(transaction: SKPaymentTransaction, plan: AccountPlan, completion: @escaping () -> Void) throws {
        let receipt = try self.readReceipt()
                
        paymentsService.createPaymentToken(amount: plan.yearlyCost, receipt: receipt, success: { [weak self] token in
            PMLog.D("StoreKit: payment token created for signup")
            self?.tokenStorage.add(token)
            
            self?.processUnauthenticated(withToken: token, transaction: transaction, plan: plan, completion: completion)
            
        }, failure: { [weak self] error in
            PMLog.ET("StoreKit: Create token failed: \(error.localizedDescription)")
            self?.tokenStorage.clear()
            self?.successCompletion?(nil)
            completion()
            // Transaction will be finished after login
        })
        
    }
    
    private func processUnauthenticated(withToken token: PaymentToken, transaction: SKPaymentTransaction, plan: AccountPlan, completion: @escaping () -> Void) {
        // In App Payment already succeeded at this point
        paymentsService.getPaymentTokenStatus(token: token, success: { [weak self] tokenStatus in
            switch tokenStatus.status {
            case .pending: // Waiting for the token to get ready to be charged (should not happen with IAP)
                let retryIn: Double = 30
                PMLog.D("StoreKit: token not ready yet. Scheduling retry in \(retryIn) seconds")
                DispatchQueue.main.asyncAfter(deadline: .now() + retryIn) {
                    self?.processUnauthenticated(withToken: token, transaction: transaction, plan: plan, completion: completion)
                }
                return
                
            case .chargeable: // Gr8 success
                self?.transactionsMadeBeforeSignup.append(transaction)
                self?.successCompletion?(token)
                completion()
                // Transaction will be finished after login
                
            default:
                PMLog.D("StoreKit: token status: \(tokenStatus.status)")
                self?.tokenStorage.clear()
                self?.successCompletion?(nil)
                completion()
                // Transaction will be finished after login
            }
                        
        }, failure: { [weak self] error in
            PMLog.ET("StoreKit: Get token info failed: \(error.localizedDescription)")
            self?.tokenStorage.clear()
            self?.successCompletion?(nil)
            completion()
            // Transaction will be finished after login
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
        guard !receiptUrl.lastPathComponent.contains("sandbox") || ApiConstants.doh.defaultHost != ApiConstants.liveURL else { // don't allow sandbox receipts on live
            throw Errors.sandboxReceipt
        }

        PMLog.D(receiptUrl.path) // make use of the receipt url so maybe compiler will not screw it up while optimising
        guard let receipt = try? Data(contentsOf: receiptUrl).base64EncodedString() else {
            throw Errors.receiptLost
        }
        
        return receipt
    }
}
