//
//  iOSNetworkingDelegate.swift
//  ProtonVPN
//
//  Created by Igor Kulman on 24.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import CommonNetworking
import Dependencies
import Domain
import Foundation
import GoLibs
import LegacyCommon
import ProtonCoreDataModel
import ProtonCoreFeatureFlags
import ProtonCoreForceUpgrade
import ProtonCoreHumanVerification
import ProtonCoreNetworking
import ProtonCoreServices
import VPNAppCore

final class iOSNetworkingDelegate: NetworkingDelegate {
    let sessionAuthenticatedEvents: AsyncStream<Bool>
    let logoutEvents: AsyncStream<Void>
    let forceUpgradeEvents: AsyncStream<String>

    private var humanVerify: HumanVerifyDelegate?

    private let sessionContinuation: AsyncStream<Bool>.Continuation
    private let logoutContinuation: AsyncStream<Void>.Continuation
    private let forceUpgradeContinuation: AsyncStream<String>.Continuation

    init() {
        let (sessionStream, sessionContinuation) = AsyncStream<Bool>.makeStream()
        self.sessionAuthenticatedEvents = sessionStream
        self.sessionContinuation = sessionContinuation

        let (logoutStream, logoutContinuation) = AsyncStream<Void>.makeStream()
        self.logoutEvents = logoutStream
        self.logoutContinuation = logoutContinuation

        let (forceUpgradeStream, forceUpgradeContinuation) = AsyncStream<String>.makeStream()
        self.forceUpgradeEvents = forceUpgradeStream
        self.forceUpgradeContinuation = forceUpgradeContinuation
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
        logoutContinuation.yield()
        sessionContinuation.yield(false)
    }

    func onGuestToAuthenticatedTransition() async {
        @Dependency(\.connectionBridge) var bridge
        await bridge.push(intent: .onSessionChange)
        log.info("Cleared VPN authentication data during guest to authenticated transition", category: .net)
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
        forceUpgradeContinuation.yield(message)
    }
}

extension CoreNetworkingDelegateKey: @retroactive DependencyKey {
    public static let liveValue: NetworkingDelegate = iOSNetworkingDelegate()
}
