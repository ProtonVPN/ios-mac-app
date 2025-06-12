//
//  iOSNetworkingDelegate.swift
//  ProtonVPN
//
//  Created by Igor Kulman on 24.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import CommonNetworking
import Domain
import Foundation
import GoLibs
import LegacyCommon
import ProtonCoreDataModel
import ProtonCoreForceUpgrade
import ProtonCoreHumanVerification
import ProtonCoreNetworking
import ProtonCoreServices
import VPNAppCore

final class iOSNetworkingDelegate: NetworkingDelegate {
    let sessionAuthenticatedEvents: AsyncStream<Bool>

    private let forceUpgradeService: ForceUpgradeDelegate
    private var humanVerify: HumanVerifyDelegate?
    private let alertingService: CoreAlertService

    private let continuation: AsyncStream<Bool>.Continuation

    init(alertingService: CoreAlertService) {
        forceUpgradeService = ForceUpgradeHelper(config: .mobile(URL(string: URLConstants.appStoreUrl)!))
        self.alertingService = alertingService

        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        sessionAuthenticatedEvents = stream
        self.continuation = continuation
    }

    func set(apiService: APIService) {
        humanVerify = HumanCheckHelper(
            apiService: apiService,
            supportURL: getSupportURL(),
            inAppTheme: { .dark },
            clientApp: ClientApp.vpn
        )
    }

    func onLogout() {
        alertingService.push(alert: RefreshTokenExpiredAlert())
        continuation.yield(false)
    }
}

extension iOSNetworkingDelegate {
    var responseDelegateForLoginAndSignup: HumanVerifyResponseDelegate? {
        get { humanVerify?.responseDelegateForLoginAndSignup }
        set { humanVerify?.responseDelegateForLoginAndSignup = newValue }
    }

    var paymentDelegateForLoginAndSignup: HumanVerifyPaymentDelegate? {
        get { humanVerify?.paymentDelegateForLoginAndSignup }
        set { humanVerify?.paymentDelegateForLoginAndSignup = newValue }
    }

    func onHumanVerify(parameters: HumanVerifyParameters, currentURL: URL?, completion: @escaping (HumanVerifyFinishReason) -> Void) {
        humanVerify?.onHumanVerify(parameters: parameters, currentURL: currentURL, completion: completion)
    }

    func getSupportURL() -> URL {
        VPNLink.support.url
    }
}

extension iOSNetworkingDelegate {
    func onForceUpgrade(message: String) {
        forceUpgradeService.onForceUpgrade(message: message)
    }
}
