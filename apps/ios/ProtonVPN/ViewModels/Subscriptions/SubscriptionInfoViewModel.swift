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
    func makeSubscriptionInfoViewModel(plan: AccountPlan, servicePlanDataStorage: ServicePlanDataStorage, vpnKeychain: VpnKeychainProtocol, storeKitManager: StoreKitManager) -> SubscriptionInfoViewModel
}

extension DependencyContainer: SubscriptionInfoViewModelFactory {
    func makeSubscriptionInfoViewModel(plan: AccountPlan, servicePlanDataStorage: ServicePlanDataStorage, vpnKeychain: VpnKeychainProtocol, storeKitManager: StoreKitManager) -> SubscriptionInfoViewModel {
        return SubscriptionInfoViewModelImplementation(plan: plan, servicePlanDataStorage: servicePlanDataStorage, vpnKeychain: vpnKeychain, storeKitManager: storeKitManager)
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
    
}

class SubscriptionInfoViewModelImplementation: SubscriptionInfoViewModel {
    
    var plan: AccountPlan
    
    private let servicePlanDataStorage: ServicePlanDataStorage
    private let vpnKeychain: VpnKeychainProtocol
    private let storeKitManager: StoreKitManager
    
    public init(plan: AccountPlan, servicePlanDataStorage: ServicePlanDataStorage, vpnKeychain: VpnKeychainProtocol, storeKitManager: StoreKitManager) {
        self.plan = plan
        self.servicePlanDataStorage = servicePlanDataStorage
        self.vpnKeychain = vpnKeychain
        self.storeKitManager = storeKitManager
    }
    
    var cancelled: (() -> Void)?
    
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
        if self.willRenewAutomcatically {
            return nil
        }
        return LocalizedString.subscritpionDescription
    }
    
    var showBuyButton: Bool {
        return true
//        return !willRenewAutomcatically && isOnYearlyPlan
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
        // Special coupon that will extent subscription
        if subscription.hasNeverendingCoupon {
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
    
}
