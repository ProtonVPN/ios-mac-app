//
//  Created on 02/05/2024.
//
//  Copyright (c) 2024 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Combine
import Dependencies
import Foundation
import struct ProtonCoreNetworking.DeviceVerifyParameters
import struct ProtonCoreNetworking.HumanVerifyParameters
import protocol ProtonCoreServices.APIService
import enum ProtonCoreServices.HumanVerifyFinishReason
import protocol ProtonCoreServices.HumanVerifyPaymentDelegate
import protocol ProtonCoreServices.HumanVerifyResponseDelegate

import CommonNetworking

final class TVOSNetworkingDelegate: NetworkingDelegate {
    let sessionAuthenticatedEvents: AsyncStream<Bool>
    let logoutEvents: AnyPublisher<Void, Never>
    let forceUpgradeEvents: AnyPublisher<String, Never>

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

    func set(apiService _: APIService) {}

    func onLogout() {
        logoutSubject.send()
        sessionContinuation.yield(false)
    }

    func onGuestToAuthenticatedTransition() async {
        @Dependency(\.connectionBridge) var bridge
        await bridge.push(intent: .onSessionChange)
    }

    func onForceUpgrade(message: String) {
        forceUpgradeSubject.send(message)
    }

    var responseDelegateForLoginAndSignup: HumanVerifyResponseDelegate?
    var paymentDelegateForLoginAndSignup: HumanVerifyPaymentDelegate?
    func onHumanVerify(parameters _: HumanVerifyParameters, currentURL _: URL?, completion _: @escaping ((HumanVerifyFinishReason) -> Void)) {}
    func onDeviceVerify(parameters _: DeviceVerifyParameters) -> String? { nil }
    func getSupportURL() -> URL { URL(string: "")! }
}

extension CoreNetworkingDelegateKey: @retroactive DependencyKey {
    public static let liveValue: NetworkingDelegate = TVOSNetworkingDelegate()
}
