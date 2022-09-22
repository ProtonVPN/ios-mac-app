//
//  macOSNetworkingDelegate.swift
//  ProtonVPN-mac
//
//  Created by Igor Kulman on 24.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import vpncore
import ProtonCore_Networking
import ProtonCore_Services

// swiftlint:disable type_name
final class macOSNetworkingDelegate: NetworkingDelegate {
    private let alertService: CoreAlertService

    init(alertService: CoreAlertService) {
        self.alertService = alertService
    }

    func onLogout() {
        alertService.push(alert: RefreshTokenExpiredAlert())
    }

    func set(apiService: APIService) {}
}
// swiftlint:enable type_name

extension macOSNetworkingDelegate {
    func onHumanVerify(parameters: HumanVerifyParameters, currentURL: URL?, completion: (@escaping (HumanVerifyFinishReason) -> Void)) {
        // there is no human verification on macOS so just show en error
        // We don't have an error message to show
        // alertService.push(alert: UserVerificationAlert(error: error))

        // report human verification as closed by the user
        // should result in the request failing with error
        completion(.verification(header: [:], verificationCodeBlock: nil))
    }

    func getSupportURL() -> URL {
        return URL(string: CoreAppConstants.ProtonVpnLinks.support)!
    }
}

extension macOSNetworkingDelegate {
    func onForceUpgrade(message: String) {
        log.debug("Force upgrade required", category: .appUpdate, metadata: ["message": "\(message)"])
        alertService.push(alert: ForceUpgradeAlert())
    }
}
