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
    var updateSubscriptionBlock: ((ServicePlanSubscription?) -> Void)?
    var updateCreditsBlock: ((Credits?) -> Void)?

    init(updateSubscriptionBlock: ((ServicePlanSubscription?) -> Void)? = nil, updateCreditsBlock: ((Credits?) -> Void)? = nil) {
        self.updateSubscriptionBlock = updateSubscriptionBlock
        self.updateCreditsBlock = updateCreditsBlock
    }

    var servicePlansDetails: [ServicePlanDetails]? {
        get {
            guard let data = UserDefaults.standard.data(forKey: "servicePlansDetails") else {
                return nil
            }
            return try? PropertyListDecoder().decode(Array<ServicePlanDetails>.self, from: data)
        }
        set {
            let data = try? PropertyListEncoder().encode(newValue)
            UserDefaults.standard.setValue(data, forKey: "servicePlansDetails")
        }
    }

    var defaultPlanDetails: ServicePlanDetails? {
        get {
            guard let data = UserDefaults.standard.data(forKey: "defaultPlanDetails") else {
                return nil
            }
            return try? PropertyListDecoder().decode(ServicePlanDetails.self, from: data)
        }
        set {
            let data = try? PropertyListEncoder().encode(newValue)
            UserDefaults.standard.setValue(data, forKey: "defaultPlanDetails")
        }
    }

    var currentSubscription: ServicePlanSubscription? {
        get {
            guard let data = UserDefaults.standard.data(forKey: "currentSubscription") else {
                return nil
            }
            return try? PropertyListDecoder().decode(ServicePlanSubscription.self, from: data)
        }
        set {
            let data = try? PropertyListEncoder().encode(newValue)
            UserDefaults.standard.setValue(data, forKey: "currentSubscription")
            self.updateSubscriptionBlock?(newValue)
        }
    }

    var isIAPUpgradePlanAvailable: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "isIAPUpgradePlanAvailable")
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: "isIAPUpgradePlanAvailable")
        }
    }

    var credits: Credits? {
        didSet {
            self.updateCreditsBlock?(credits)
        }
    }
}
