//
//  iOSNetworkingDelegate.swift
//  ProtonVPN
//
//  Created by Igor Kulman on 24.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Combine
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
    let logoutEvents: AnyPublisher<Void, Never>
    let forceUpgradeEvents: AnyPublisher<String, Never>

    private var humanVerify: HumanVerifyDelegate?

    private let sessionContinuation: AsyncStream<Bool>.Continuation
    private let logoutSubject = PassthroughSubject<Void, Never>()
    private let forceUpgradeSubject = PassthroughSubject<String, Never>()

    init() {
        let (sessionStream, sessionContinuation) = AsyncStream<Bool>.makeStream()
        self.sessionAuthenticatedEvents = sessionStream
        self.sessionContinuation = sessionContinuation

        self.logoutEvents = logoutSubject.eraseToAnyPublisher()
        self.forceUpgradeEvents = forceUpgradeSubject.eraseToAnyPublisher()
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
        logoutSubject.send()
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
        forceUpgradeSubject.send(message)
    }
}

extension CoreNetworkingDelegateKey: @retroactive DependencyKey {
    public static let liveValue: NetworkingDelegate = iOSNetworkingDelegate()
}
