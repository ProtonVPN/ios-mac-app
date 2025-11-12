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

import Foundation

import Dependencies

import ProtonCoreNetworking
import ProtonCoreServices

public protocol NetworkingDelegate: ForceUpgradeDelegate, HumanVerifyDelegate {
    var sessionAuthenticatedEvents: AsyncStream<Bool> { get }
    func set(apiService: APIService)
    func onLogout()

    /// Called when transitioning from guest mode to authenticated mode
    /// This allows the delegate to clear VPN authentication data to prevent key conflicts
    func onGuestToAuthenticatedTransition() async
}

public protocol NetworkingDelegateFactory {
    func makeNetworkingDelegate() -> NetworkingDelegate
}

public protocol NetworkingFactory {
    func makeNetworking() -> Networking
}

public final class CoreNetworkingDelegateMock: NetworkingDelegate {
    public let sessionAuthenticatedEvents: AsyncStream<Bool>
    private let continuation: AsyncStream<Bool>.Continuation

    public init() {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        self.sessionAuthenticatedEvents = stream
        self.continuation = continuation
    }

    public func set(apiService _: APIService) {}
    public func onLogout() {
        continuation.yield(with: .success(false))
    }

    public func onGuestToAuthenticatedTransition() async {}

    public func onForceUpgrade(message _: String) {}

    public var responseDelegateForLoginAndSignup: HumanVerifyResponseDelegate?
    public var paymentDelegateForLoginAndSignup: HumanVerifyPaymentDelegate?
    public func onHumanVerify(parameters _: HumanVerifyParameters, currentURL _: URL?, completion _: @escaping ((HumanVerifyFinishReason) -> Void)) {}
    public func onDeviceVerify(parameters _: DeviceVerifyParameters) -> String? { nil }
    public func getSupportURL() -> URL { URL(string: "")! }
}

public enum CoreNetworkingDelegateKey: TestDependencyKey {
    public static let testValue: NetworkingDelegate = CoreNetworkingDelegateMock()
}

public extension DependencyValues {
    var networkingDelegate: NetworkingDelegate {
        get { self[CoreNetworkingDelegateKey.self] }
        set { self[CoreNetworkingDelegateKey.self] = newValue }
    }
}
