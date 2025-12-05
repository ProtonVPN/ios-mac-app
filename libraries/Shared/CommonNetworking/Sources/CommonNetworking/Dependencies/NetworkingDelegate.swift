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
    var logoutEvents: AsyncStream<Void> { get }
    var forceUpgradeEvents: AsyncStream<String> { get }
    func set(apiService: APIService)
    func onLogout()

    /// Called when transitioning from guest mode to authenticated mode
    /// This allows the delegate to clear VPN authentication data to prevent key conflicts
    func onGuestToAuthenticatedTransition() async
}

public final class CoreNetworkingDelegateMock: NetworkingDelegate {
    public let sessionAuthenticatedEvents: AsyncStream<Bool>
    public let logoutEvents: AsyncStream<Void>
    public let forceUpgradeEvents: AsyncStream<String>
    private let continuation: AsyncStream<Bool>.Continuation
    private let logoutContinuation: AsyncStream<Void>.Continuation
    private let forceUpgradeContinuation: AsyncStream<String>.Continuation

    public init() {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        self.sessionAuthenticatedEvents = stream
        self.continuation = continuation

        let (logoutStream, logoutContinuation) = AsyncStream<Void>.makeStream()
        self.logoutEvents = logoutStream
        self.logoutContinuation = logoutContinuation

        let (forceUpgradeStream, forceUpgradeContinuation) = AsyncStream<String>.makeStream()
        self.forceUpgradeEvents = forceUpgradeStream
        self.forceUpgradeContinuation = forceUpgradeContinuation
    }

    public func set(apiService _: APIService) {}
    public func onLogout() {
        logoutContinuation.yield()
        continuation.yield(with: .success(false))
    }

    public func onGuestToAuthenticatedTransition() async {}

    public func onForceUpgrade(message: String) {
        forceUpgradeContinuation.yield(message)
    }

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
