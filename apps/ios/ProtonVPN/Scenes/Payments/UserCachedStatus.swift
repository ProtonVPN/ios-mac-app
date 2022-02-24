//
//  UserCachedStatus.swift
//  ProtonVPN
//
//  Created by Igor Kulman on 01.09.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import ProtonCore_Payments
import ProtonCore_PaymentsUI
import vpncore

final class UserCachedStatus: ServicePlanDataStorage {
    enum UserCachedStatusKeys: String, CaseIterable {
        case servicePlansDetails
        case defaultPlanDetails
        case currentSubscription
        case paymentsBackendStatusAcceptsIAP
        case paymentMethods
    }

    private let storage: Storage

    init(storage: Storage) {
        self.storage = storage
    }

    var servicePlansDetails: [Plan]? {
        get {
            return storage.getDecodableValue([Plan].self, forKey: UserCachedStatusKeys.servicePlansDetails.rawValue)
        }
        set {
            storage.setEncodableValue(newValue, forKey: UserCachedStatusKeys.servicePlansDetails.rawValue)
        }
    }

    var defaultPlanDetails: Plan? {
        get {
            return storage.getDecodableValue(Plan.self, forKey: UserCachedStatusKeys.defaultPlanDetails.rawValue)
        }
        set {
            storage.setEncodableValue(newValue, forKey: UserCachedStatusKeys.defaultPlanDetails.rawValue)
        }
    }

    var currentSubscription: Subscription? {
        get {
            return storage.getDecodableValue(Subscription.self, forKey: UserCachedStatusKeys.currentSubscription.rawValue)
        }
        set {
            storage.setEncodableValue(newValue, forKey: UserCachedStatusKeys.currentSubscription.rawValue)
        }
    }

    var paymentsBackendStatusAcceptsIAP: Bool {
        get {
            return storage.defaults.bool(forKey: UserCachedStatusKeys.paymentsBackendStatusAcceptsIAP.rawValue)
        }
        set {
            storage.setValue(newValue, forKey: UserCachedStatusKeys.paymentsBackendStatusAcceptsIAP.rawValue)
        }
    }

    var paymentMethods: [PaymentMethod]? {
        get {
            return storage.getDecodableValue([PaymentMethod].self, forKey: UserCachedStatusKeys.paymentMethods.rawValue)
        }
        set {
            storage.setEncodableValue(newValue, forKey: UserCachedStatusKeys.paymentMethods.rawValue)
        }
    }

    var credits: Credits?

    func clear() {
        for key in UserCachedStatusKeys.allCases {
            storage.defaults.removeObject(forKey: key.rawValue)
        }
    }
}
