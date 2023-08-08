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
        case paymentsBackendStatusAcceptsIAP
        case paymentMethods
    }

    var servicePlansDetails: [Plan]? {
        get {
            return try? storage.get([Plan].self, forKey: UserCachedStatusKeys.servicePlansDetails.rawValue)
        }
        set {
            try? storage.set(newValue, forKey: UserCachedStatusKeys.servicePlansDetails.rawValue)
        }
    }

    var defaultPlanDetails: Plan? {
        get {
            return try? storage.get(Plan.self, forKey: UserCachedStatusKeys.defaultPlanDetails.rawValue)
        }
        set {
            try? storage.set(newValue, forKey: UserCachedStatusKeys.defaultPlanDetails.rawValue)
        }
    }

    var currentSubscription: Subscription? {
        get {
            return try? storage.get(Subscription.self, forKey: UserCachedStatusKeys.currentSubscription.rawValue)
        }
        set {
            try? storage.set(newValue, forKey: UserCachedStatusKeys.currentSubscription.rawValue)
        }
    }

    var paymentsBackendStatusAcceptsIAP: Bool {
        get {
            return provider.getDefaults().bool(forKey: UserCachedStatusKeys.paymentsBackendStatusAcceptsIAP.rawValue)
        }
        set {
            provider.getDefaults().set(newValue, forKey: UserCachedStatusKeys.paymentsBackendStatusAcceptsIAP.rawValue)
        }
    }

    var paymentMethods: [PaymentMethod]? {
        get {
            return try? storage.get([PaymentMethod].self, forKey: UserCachedStatusKeys.paymentMethods.rawValue)
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
