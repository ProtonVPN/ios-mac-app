//
//  macOSNetworkingDelegate.swift
//  ProtonVPN-mac
//
//  Created by Igor Kulman on 24.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import LegacyCommon
import ProtonCoreNetworking
import ProtonCoreServices
import CommonNetworking

// swiftlint:disable type_name
final class macOSNetworkingDelegate: NetworkingDelegate {
    let sessionAuthenticatedEvents: AsyncStream<Bool>

    // these belong to HumanVerifyDelegate
    weak var responseDelegateForLoginAndSignup: HumanVerifyResponseDelegate?
    weak var paymentDelegateForLoginAndSignup: HumanVerifyPaymentDelegate?

    private let alertService: CoreAlertService

    private let continuation: AsyncStream<Bool>.Continuation

    init(alertService: CoreAlertService) {
        self.alertService = alertService
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        self.sessionAuthenticatedEvents = stream
        self.continuation = continuation
    }

    func onLogout() {
        alertService.push(alert: RefreshTokenExpiredAlert())
        continuation.yield(false)
    }

    func set(apiService: APIService) {}
}
// swiftlint:enable type_name

extension macOSNetworkingDelegate {
    func onHumanVerify(parameters: HumanVerifyParameters, currentURL: URL?, completion: (@escaping (HumanVerifyFinishReason) -> Void)) {
        // report human verification as closed by the user
        // should result in the request failing with error
        completion(.verification(header: [:], verificationCodeBlock: nil))
    }

    func onDeviceVerify(parameters: DeviceVerifyParameters) -> String? {
        // we simulate the device not computing the pow
        nil
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
