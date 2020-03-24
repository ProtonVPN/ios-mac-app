//
//  SubscriptionInfoViewModel.swift
//  ProtonVPN - Created on 2020-03-09.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
import vpncore

protocol SubscriptionInfoViewModelFactory {
    func makeSubscriptionInfoViewModel(plan: AccountPlan) -> SubscriptionInfoViewModel
}

extension DependencyContainer: SubscriptionInfoViewModelFactory {
    func makeSubscriptionInfoViewModel(plan: AccountPlan) -> SubscriptionInfoViewModel {
        return SubscriptionInfoViewModelImplementation(plan: plan, factory: self)
    }
}

protocol SubscriptionInfoViewModel: class {
    
    var plan: AccountPlan { get }
    var expirationText: String? { get }
    var description: String? { get }
    var footerText: String? { get }
    var showBuyButton: Bool { get }
    var planPrice: String { get }
    
    var cancelled: (() -> Void)? { get set }
    func cancel()
    
    var showSuccess: ((String) -> Void)? { get set }
    var showError: ((Error) -> Void)? { get set }
    var loadingStateChanged: ((Bool) -> Void)? { get set }
    
    func startBuy()
}

class SubscriptionInfoViewModelImplementation: SubscriptionInfoViewModel {
    
    var plan: AccountPlan
    
    // Callbacks
    var showSuccess: ((String) -> Void)?
    var showError: ((Error) -> Void)?
    var cancelled: (() -> Void)?
    
    // Loading indicator
    var isLoading = false { didSet { DispatchQueue.main.async { self.loadingStateChanged?(self.isLoading) } } }
    var loadingStateChanged: ((Bool) -> Void)?
    
    // Factory
    typealias Factory = StoreKitManagerFactory & PaymentsApiServiceFactory & ServicePlanDataStorageFactory & VpnKeychainFactory & AppSessionManagerFactory
    private let factory: Factory
    
    // Dependencies
    private lazy var servicePlanDataStorage: ServicePlanDataStorage = factory.makeServicePlanDataStorage()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var storeKitManager: StoreKitManager = factory.makeStoreKitManager()
    private lazy var paymentsApiService: PaymentsApiService = factory.makePaymentsApiService()
    private lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    
    public init(plan: AccountPlan, factory: Factory) {
        self.plan = plan
        self.factory = factory
    }
    
    func cancel() {
        cancelled?()
    }
    
    var expirationText: String? {
        guard let subscription = servicePlanDataStorage.currentSubscription else {
            return nil
        }
        
        if let endDate = subscription.endDate, endDate.isFuture {
            if self.willRenewAutomcatically {
                return String(format: LocalizedString.subscritpionWillRenew, endDate.formattedShortDate)
            }
            return String(format: LocalizedString.subscritpionWillExpire, endDate.formattedShortDate)
        }
        
        return nil
    }
    
    var description: String? {
        guard showBuyButton else {
            return nil
        }
        return LocalizedString.subscritpionDescription
    }
    
    var showBuyButton: Bool {
        return !willRenewAutomcatically && isOnYearlyPlan
    }
    
    var footerText: String? {
        guard showBuyButton else {
            return nil
        }
        return LocalizedString.plansFooter
    }
    
    var planPrice: String {
        guard showBuyButton else {
            return ""
        }
        guard let productId = plan.storeKitProductId, let price = storeKitManager.priceLabelForProduct(id: productId) else {
            return ""
        }
            
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = price.1
        formatter.maximumFractionDigits = 2
            
        let total = price.0 as Decimal
        let priceString = formatter.string(from: total as NSNumber) ?? ""
        
        return priceString
    }
    
    // MARK: Condition checks
    
    private var willRenewAutomcatically: Bool {
        guard let subscription = servicePlanDataStorage.currentSubscription else {
            return false
        }
        // Special coupon that will extend subscription
        if subscription.hasSpecialCoupon {
            return true
        }
        // User has payment method setup that will extend subscription automatically
        if !(subscription.paymentMethods?.isEmpty ?? true) {
            return true
        }
        // Has credit that will be used for renewal
        if self.hasEnoughCreditToExtendSubscription {
            return true
        }
        return false
    }
    
    private var isOnYearlyPlan: Bool {
        return servicePlanDataStorage.currentSubscription?.cycle == 12
    }
    
    private var hasEnoughCreditToExtendSubscription: Bool {
        let credit = (try? vpnKeychain.fetch().credit) ?? 0
        return credit >= plan.yearlyCost
    }
    
    // MARK: Buy
    
    public func startBuy() {
        guard plan.paid, let productId = plan.storeKitProductId else {
            PMLog.ET("IAP errored", level: .error)
            self.failed(withError: nil)
            return
        }
        isLoading = true

        storeKitManager.subscribeToPaymentQueue()
        storeKitManager.purchaseProduct(withId: productId, refreshHandler: { [weak self] in
            self?.failed(withError: nil)

        }, successCompletion: { [weak self] _ in
            PMLog.ET("IAP succeeded", level: .info)
            self?.reload()
            
        }, errorCompletion: { [weak self] (error) in
            PMLog.ET("IAP errored: \(error.localizedDescription)")
            self?.failed(withError: error)

        }, deferredCompletion: {
            PMLog.ET("IAP deferred", level: .warn)

        })
    }
    
    private func failed(withError error: Error?) {
        isLoading = false
        if let error = error {
            DispatchQueue.main.async {
                self.showError?(error)
            }
        }
    }
    
    private func reload(showSuccessfullPayment: Bool = true) {
        isLoading = true
        let successMessage = String(format: LocalizedString.subscritpionExtendSuccess, servicePlanDataStorage.currentSubscription?.endDate?.formattedShortDate ?? "")
        
        appSessionManager.loadDataWithoutLogin(success: { [weak self] in
            self?.isLoading = false
            if showSuccessfullPayment {
                self?.showSuccess?(successMessage)
            }
            
        }, failure: { [weak self] error in
            self?.isLoading = false
            if showSuccessfullPayment { // Payment went successfully, this is error on reaload info only
                self?.showSuccess?(successMessage)
            } else {
                self?.showError?(error)
            }
        })
    }
    
}
