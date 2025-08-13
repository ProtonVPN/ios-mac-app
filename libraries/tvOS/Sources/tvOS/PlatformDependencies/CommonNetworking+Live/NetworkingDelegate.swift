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
    private let continuation: AsyncStream<Bool>.Continuation

    init() {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        self.sessionAuthenticatedEvents = stream
        self.continuation = continuation
    }

    func set(apiService _: APIService) {}

    func onLogout() {
        continuation.yield(false)
    }

    func onGuestToAuthenticatedTransition() {
        @Dependency(\.connectionBridge) var bridge
        Task {
            await bridge.push(intent: .onSessionChange)
        }
    }

    func onForceUpgrade(message _: String) {}

    var responseDelegateForLoginAndSignup: HumanVerifyResponseDelegate?
    var paymentDelegateForLoginAndSignup: HumanVerifyPaymentDelegate?
    func onHumanVerify(parameters _: HumanVerifyParameters, currentURL _: URL?, completion _: @escaping ((HumanVerifyFinishReason) -> Void)) {}
    func onDeviceVerify(parameters _: DeviceVerifyParameters) -> String? { nil }
    func getSupportURL() -> URL { URL(string: "")! }
}

extension CoreNetworkingDelegateKey: DependencyKey {
    public static let liveValue: NetworkingDelegate = TVOSNetworkingDelegate()
}
