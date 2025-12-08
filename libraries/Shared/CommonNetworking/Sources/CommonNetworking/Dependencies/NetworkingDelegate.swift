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
import Foundation

import Dependencies

import ProtonCoreNetworking
import ProtonCoreServices

public protocol NetworkingDelegate: ForceUpgradeDelegate, HumanVerifyDelegate {
    var sessionAuthenticatedEvents: AsyncStream<Bool> { get }
    var logoutEvents: AnyPublisher<Void, Never> { get }
    var forceUpgradeEvents: AnyPublisher<String, Never> { get }
    func set(apiService: APIService)
    func onLogout()

    /// Called when transitioning from guest mode to authenticated mode
    /// This allows the delegate to clear VPN authentication data to prevent key conflicts
    func onGuestToAuthenticatedTransition() async
}

public final class CoreNetworkingDelegateMock: NetworkingDelegate {
    public let sessionAuthenticatedEvents: AsyncStream<Bool>
    public let logoutEvents: AnyPublisher<Void, Never>
    public let forceUpgradeEvents: AnyPublisher<String, Never>
    private let continuation: AsyncStream<Bool>.Continuation
    private let logoutSubject = PassthroughSubject<Void, Never>()
    private let forceUpgradeSubject = PassthroughSubject<String, Never>()

    public init() {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        self.sessionAuthenticatedEvents = stream
        self.continuation = continuation

        self.logoutEvents = logoutSubject.eraseToAnyPublisher()
        self.forceUpgradeEvents = forceUpgradeSubject.eraseToAnyPublisher()
    }

    public func set(apiService _: APIService) {}
    public func onLogout() {
        logoutSubject.send()
        continuation.yield(with: .success(false))
    }

    public func onGuestToAuthenticatedTransition() async {}

    public func onForceUpgrade(message: String) {
        forceUpgradeSubject.send(message)
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
