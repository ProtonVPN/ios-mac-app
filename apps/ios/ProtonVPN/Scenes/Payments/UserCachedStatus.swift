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

final class UserCachedStatus: ServicePlanDataStorage {
    enum UserCachedStatusKeys: String, CaseIterable {
        case servicePlansDetails
        case defaultPlanDetails
        case currentSubscription
        case isIAPUpgradePlanAvailable
    }

    var updateSubscriptionBlock: ((Subscription?) -> Void)?
    var updateCreditsBlock: ((Credits?) -> Void)?

    init(updateSubscriptionBlock: ((Subscription?) -> Void)? = nil, updateCreditsBlock: ((Credits?) -> Void)? = nil) {
        self.updateSubscriptionBlock = updateSubscriptionBlock
        self.updateCreditsBlock = updateCreditsBlock
    }

    var servicePlansDetails: [Plan]? {
        get {
            guard let data = UserDefaults.standard.data(forKey: UserCachedStatusKeys.servicePlansDetails.rawValue) else {
                return nil
            }
            return try? PropertyListDecoder().decode(Array<Plan>.self, from: data)
        }
        set {
            let data = try? PropertyListEncoder().encode(newValue)
            UserDefaults.standard.setValue(data, forKey: UserCachedStatusKeys.servicePlansDetails.rawValue)
        }
    }

    var defaultPlanDetails: Plan? {
        get {
            guard let data = UserDefaults.standard.data(forKey: UserCachedStatusKeys.defaultPlanDetails.rawValue) else {
                return nil
            }
            return try? PropertyListDecoder().decode(Plan.self, from: data)
        }
        set {
            let data = try? PropertyListEncoder().encode(newValue)
            UserDefaults.standard.setValue(data, forKey: UserCachedStatusKeys.defaultPlanDetails.rawValue)
        }
    }

    var currentSubscription: Subscription? {
        get {
            guard let data = UserDefaults.standard.data(forKey: UserCachedStatusKeys.currentSubscription.rawValue) else {
                return nil
            }
            return try? PropertyListDecoder().decode(Subscription.self, from: data)
        }
        set {
            let data = try? PropertyListEncoder().encode(newValue)
            UserDefaults.standard.setValue(data, forKey: UserCachedStatusKeys.currentSubscription.rawValue)
            self.updateSubscriptionBlock?(newValue)
        }
    }

    var isIAPUpgradePlanAvailable: Bool {
        get {
            return UserDefaults.standard.bool(forKey: UserCachedStatusKeys.isIAPUpgradePlanAvailable.rawValue)
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: UserCachedStatusKeys.isIAPUpgradePlanAvailable.rawValue)
        }
    }

    var credits: Credits? {
        didSet {
            self.updateCreditsBlock?(credits)
        }
    }

    func clear() {
        for key in UserCachedStatusKeys.allCases {
            UserDefaults.standard.removeObject(forKey: key.rawValue)
        }
    }
}
