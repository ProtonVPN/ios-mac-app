//
//  iOSNetworkingDelegate.swift
//  ProtonVPN
//
//  Created by Igor Kulman on 24.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import vpncore
import ProtonCore_Networking
import ProtonCore_Services
import ProtonCore_ForceUpgrade
import ProtonCore_HumanVerification

final class iOSNetworkingDelegate: NetworkingDelegate {
    private let forceUpgradeService: ForceUpgradeDelegate
    private var humanVerify: HumanVerifyDelegate?

    init() {
        forceUpgradeService = ForceUpgradeHelper(config: .mobile(URL(string: URLConstants.appStoreUrl)!))
    }

    func set(apiService: APIService) {
        humanVerify = HumanCheckHelper(apiService: apiService, supportURL: getSupportURL())
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
