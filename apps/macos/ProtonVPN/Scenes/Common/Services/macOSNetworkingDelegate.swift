//
//  macOSNetworkingDelegate.swift
//  ProtonVPN-mac
//
//  Created by Igor Kulman on 24.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Combine
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
    let logoutEvents: AnyPublisher<Void, Never>
    let forceUpgradeEvents: AnyPublisher<String, Never>

    // these belong to HumanVerifyDelegate
    weak var responseDelegateForLoginAndSignup: HumanVerifyResponseDelegate?
    weak var paymentDelegateForLoginAndSignup: HumanVerifyPaymentDelegate?

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

    func onLogout() {
        logoutSubject.send()
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
        forceUpgradeSubject.send(message)
    }
}

extension CoreNetworkingDelegateKey: @retroactive DependencyKey {
    public static let liveValue: NetworkingDelegate = macOSNetworkingDelegate()
}
