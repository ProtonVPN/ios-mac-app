//
//  UserCachedStatus.swift
//  ProtonVPN
//
//  Created by Igor Kulman on 01.09.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import Dependencies
import ProtonCorePayments
import ProtonCorePaymentsUI
import LegacyCommon
import VPNShared

final class UserCachedStatus: ServicePlanDataStorage {
    @Dependency(\.storage) var storage
    @Dependency(\.defaultsProvider) var provider

    enum UserCachedStatusKeys: String, CaseIterable {
        case servicePlansDetails
        case defaultPlanDetails
        case currentSubscription
        case iapSupportStatus
        case paymentMethods
        /// - Note: this value has been replaced by `iapSupportStatus`.
        case paymentsBackendStatusAcceptsIAP
    }

    var servicePlansDetails: [Plan]? {
        get {
            try? storage.get([Plan].self, forKey: UserCachedStatusKeys.servicePlansDetails.rawValue)
        }
        set {
            try? storage.set(newValue, forKey: UserCachedStatusKeys.servicePlansDetails.rawValue)
        }
    }

    var defaultPlanDetails: Plan? {
        get {
            try? storage.get(Plan.self, forKey: UserCachedStatusKeys.defaultPlanDetails.rawValue)
        }
        set {
            try? storage.set(newValue, forKey: UserCachedStatusKeys.defaultPlanDetails.rawValue)
        }
    }

    var currentSubscription: Subscription? {
        get {
            try? storage.get(Subscription.self, forKey: UserCachedStatusKeys.currentSubscription.rawValue)
        }
        set {
            try? storage.set(newValue, forKey: UserCachedStatusKeys.currentSubscription.rawValue)
        }
    }

    var iapSupportStatus: IAPSupportStatus {
        get {
            // First, try to get the newer `iapSupportStatus` default.
            if let status = try? storage.get(IAPSupportStatus.self, forKey: UserCachedStatusKeys.iapSupportStatus.rawValue) {
                return status
            }
            // If we can't find it, then fall back to the old value with a nil reason.
            guard provider.getDefaults().bool(forKey: UserCachedStatusKeys.paymentsBackendStatusAcceptsIAP.rawValue) else {
                return .disabled(localizedReason: nil)
            }
            return .enabled
        }
        set {
            try? storage.set(newValue, forKey: UserCachedStatusKeys.iapSupportStatus.rawValue)
        }
    }

    var paymentMethods: [PaymentMethod]? {
        get {
            try? storage.get([PaymentMethod].self, forKey: UserCachedStatusKeys.paymentMethods.rawValue)
        }
        set {
            try? storage.set(newValue, forKey: UserCachedStatusKeys.paymentMethods.rawValue)
        }
    }

    var credits: Credits?

    func clear() {
        for key in UserCachedStatusKeys.allCases {
            storage.removeObject(forKey: key.rawValue)
        }
    }
}
