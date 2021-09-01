//
//  iOSNetworkingDelegate.swift
//  ProtonVPN
//
//  Created by Igor Kulman on 24.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import vpncore
import WireguardCrypto
import ProtonCore_Networking
import ProtonCore_Services
import ProtonCore_ForceUpgrade
import ProtonCore_HumanVerification
import ProtonCore_Payments
import ProtonCore_PaymentsUI

final class iOSNetworkingDelegate: NetworkingDelegate {
    private let forceUpgradeService: ForceUpgradeDelegate
    private var humanVerify: HumanVerifyDelegate?
    private let alertingService: CoreAlertService
    private var apiService: APIService?

    init(alertingService: CoreAlertService) {
        self.forceUpgradeService = ForceUpgradeHelper(config: .mobile(URL(string: URLConstants.appStoreUrl)!))
        self.alertingService = alertingService
    }

    func set(apiService: APIService) {
        humanVerify = HumanCheckHelper(apiService: apiService, supportURL: getSupportURL())
        self.apiService = apiService
    }

    func onLogout() {
        alertingService.push(alert: RefreshTokenExpiredAlert())
    }

    func getAPIService() -> APIService {
        return apiService!
    }
}

extension iOSNetworkingDelegate {
    func onHumanVerify(methods: [VerifyMethod], startToken: String?, completion: @escaping ((HumanVerifyHeader, HumanVerifyIsClosed, SendVerificationCodeBlock?) -> Void)) {
        humanVerify?.onHumanVerify(methods: methods, startToken: startToken, completion: completion)
    }

    func getSupportURL() -> URL {
        return URL(string: CoreAppConstants.ProtonVpnLinks.support)!
    }
}

extension iOSNetworkingDelegate {
    func onForceUpgrade(message: String) {
        forceUpgradeService.onForceUpgrade(message: message)
    }
}
