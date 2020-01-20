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
    func subscribeToPaymentQueue()
    func purchaseProduct(withId id: String, refreshHandler: @escaping () -> Void, successCompletion: @escaping (String?) -> Void, errorCompletion: @escaping (Error) -> Void, deferredCompletion: @escaping () -> Void)
    func processAllTransactions()
    func processAllTransactions(_ finishHandler: (() -> Void)?)
    func updateAvailableProductsList()
    func readyToPurchaseProduct() -> Bool
    func priceLabelForProduct(id: String) -> (NSDecimalNumber, Locale)?
}

public class StoreKitManagerImplementation: NSObject, StoreKitManager {
   
    public typealias Factory = CoreAlertServiceFactory & PaymentsApiServiceFactory
    private let factory: Factory
        
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var paymentsService: PaymentsApiService = factory.makePaymentsApiService()
        
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
    private var successCompletion: ((String?) -> Void)?
    private var deferredCompletion: (() -> Void)?
    private lazy var errorCompletion: (Error) -> Void = { error in
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
    
    public func purchaseProduct(withId id: String,
                                refreshHandler: @escaping () -> Void,
                                successCompletion: @escaping (String?) -> Void,
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
        
        transactionsFinishHandler = finishHandler
        SKPaymentQueue.default().transactions.forEach { transaction in
            self.addOperation { self.process(transaction) }
        }
    }
    
    public func processAllTransactions() {
        processAllTransactions(transactionsFinishHandler)
    }
    
    /// Adds operation to queue plus adds additional operation that check if queue is empty and calls finish handler ir available
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
        case .existingUser:
            
            if transactionsMadeBeforeSignup.contains(transaction) {
                processAuthenticatedBeforeSignup(transaction: transaction, plan: plan)
            } else {
                try processAuthenticated(transaction: transaction, plan: plan, planId: planId)
            }
        case .registration:
            try processUnauthenticated(transaction: transaction, plan: plan)
        }
        
    }
    
    private func processAuthenticated(transaction: SKPaymentTransaction, plan: AccountPlan, planId: String) throws {
        let receipt = try self.readReceipt()
        // payments/subscription
        paymentsService.postReceipt(amount: plan.yearlyCost, receipt: receipt, planId: planId, success: { [weak self] subscription in
            ServicePlanDataServiceImplementation.shared.currentSubscription = subscription
            self?.successCompletion?(nil)
            SKPaymentQueue.default().finishTransaction(transaction)
        }, failure: { [weak self] (error) in
            guard let `self` = self else { return }
            switch (error as NSError).code {
            case 22101:
                // ammount mismatch - try report only credits without activating the plan
                self.paymentsService.credit(amount: plan.yearlyCost, receipt: receipt, success: {
                    self.errorCompletion(Errors.creditsApplied)
                    SKPaymentQueue.default().finishTransaction(transaction)
                }, failure: { (error) in
                    if (error as NSError).code == 22916 { // Apple payment already registered
                        SKPaymentQueue.default().finishTransaction(transaction)
                    } else {
                        self.errorCompletion(error)
                    }
                })
            case 22914: // sandbox receipt sent to BE
                SKPaymentQueue.default().finishTransaction(transaction)
                self.errorCompletion(error)
            case 22916: // Apple payment already registered
                SKPaymentQueue.default().finishTransaction(transaction)
            default:
                self.errorCompletion(error)
            }
        })
    }
    
    private func processAuthenticatedBeforeSignup(transaction: SKPaymentTransaction, plan: AccountPlan) {
        guard let details = plan.fetchDetails(), let planId = details.iD else {
            PMLog.ET("Can't fetch plan details")
            return
        }
        paymentsService.applyCredit(forPlanId: planId, success: { [weak self] subscription in
            self?.finish(transaction: transaction)
            
        }, failure: {[weak self] error in
            PMLog.ET("Apply credit failed")
            
            self?.alertService.push(alert: ApplyCreditAfterRegistrationFailedAlert(
                retryHandler: {
                    self?.processAuthenticatedBeforeSignup(transaction: transaction, plan: plan)
                },
                supportHandler: {
                    self?.finish(transaction: transaction)
                    self?.alertService.push(alert: ReportBugAlert())
                })
            )
        })
    }
    
    private func finish(transaction: SKPaymentTransaction) {
        SKPaymentQueue.default().finishTransaction(transaction)
        transactionsMadeBeforeSignup.removeAll(where: { $0 == transaction })
    }
    
    private func processUnauthenticated(transaction: SKPaymentTransaction, plan: AccountPlan) throws {
        let receipt = try self.readReceipt()
        
        paymentsService.verifyPayment(amount: plan.yearlyCost, receipt: receipt, success: { [weak self] verificationCode in
            self?.successCompletion?(verificationCode)
            self?.transactionsMadeBeforeSignup.append(transaction)
            // Transaction will be finished after login
            
        }, failure: { [weak self] error in
            self?.errorCompletion(error)
        })
    }
    
    var processingType: ProcessingType {
        if let userId = AuthKeychain.fetch()?.userId, !userId.isEmpty {
            return .existingUser
        }
        return .registration
    }
    
    enum ProcessingType {
        case existingUser
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
