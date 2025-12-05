//
//  macOSNetworkingDelegate.swift
//  ProtonVPN-mac
//
//  Created by Igor Kulman on 24.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import CommonNetworking
import Dependencies
import Domain
import Foundation
import LegacyCommon
import ProtonCoreNetworking
import ProtonCoreServices
import VPNAppCore

// swiftlint:disable type_name
final class macOSNetworkingDelegate: NetworkingDelegate {
    let sessionAuthenticatedEvents: AsyncStream<Bool>
    let logoutEvents: AsyncStream<Void>
    let forceUpgradeEvents: AsyncStream<String>

    // these belong to HumanVerifyDelegate
    weak var responseDelegateForLoginAndSignup: HumanVerifyResponseDelegate?
    weak var paymentDelegateForLoginAndSignup: HumanVerifyPaymentDelegate?

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

    func onLogout() {
        logoutContinuation.yield()
        sessionContinuation.yield(false)
    }

    func onGuestToAuthenticatedTransition() async {
        @Dependency(\.vpnAuthenticationStorage) var authenticationStorage
        authenticationStorage.deleteKeys()
        authenticationStorage.deleteCertificate()
        log.info("Cleared VPN authentication data during guest to authenticated transition", category: .net)
    }

    func set(apiService _: APIService) {}
}

// swiftlint:enable type_name

extension macOSNetworkingDelegate {
    func onHumanVerify(parameters _: HumanVerifyParameters, currentURL _: URL?, completion: @escaping (HumanVerifyFinishReason) -> Void) {
        // report human verification as closed by the user
        // should result in the request failing with error
        completion(.verification(header: [:], verificationCodeBlock: nil))
    }

    func onDeviceVerify(parameters _: DeviceVerifyParameters) -> String? {
        // we simulate the device not computing the pow
        nil
    }

    func getSupportURL() -> URL {
        VPNLink.support.url
    }
}

extension macOSNetworkingDelegate {
    func onForceUpgrade(message: String) {
        log.debug("Force upgrade required", category: .appUpdate, metadata: ["message": "\(message)"])
        forceUpgradeContinuation.yield(message)
    }
}

extension CoreNetworkingDelegateKey: @retroactive DependencyKey {
    public static let liveValue: NetworkingDelegate = macOSNetworkingDelegate()
}
