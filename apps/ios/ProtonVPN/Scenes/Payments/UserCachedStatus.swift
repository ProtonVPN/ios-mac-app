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
            getData(key: .servicePlansDetails)
        }
        set {
            setData(key: .servicePlansDetails, value: newValue)
        }
    }

    var defaultPlanDetails: Plan? {
        get {
            getData(key: .defaultPlanDetails)
        }
        set {
            setData(key: .defaultPlanDetails, value: newValue)
        }
    }

    var currentSubscription: Subscription? {
        get {
            getData(key: .currentSubscription)
        }
        set {
            setData(key: .currentSubscription, value: newValue)
            updateSubscriptionBlock?(newValue)
        }
    }

    var isIAPUpgradePlanAvailable: Bool {
        get {
            return Storage.userDefaults().bool(forKey: UserCachedStatusKeys.isIAPUpgradePlanAvailable.rawValue)
        }
        set {
            Storage.setValue(newValue, forKey: UserCachedStatusKeys.isIAPUpgradePlanAvailable.rawValue)
        }
    }

    var credits: Credits? {
        didSet {
            self.updateCreditsBlock?(credits)
        }
    }

    func clear() {
        for key in UserCachedStatusKeys.allCases {
            Storage.userDefaults().removeObject(forKey: key.rawValue)
        }
    }

    private func getData<A: Decodable>(key: UserCachedStatusKeys) -> A? {
        guard let data = Storage.userDefaults().data(forKey: key.rawValue) else {
            return nil
        }
        return try? JSONDecoder().decode(A.self, from: data)
    }

    private func setData<A: Encodable>(key: UserCachedStatusKeys, value: A) {
        let data = try? JSONEncoder().encode(value)
        Storage.setValue(data, forKey: key.rawValue)
    }
}
