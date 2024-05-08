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
    func set(apiService: APIService)
    func onLogout()
}

public protocol NetworkingDelegateFactory {
    func makeNetworkingDelegate() -> NetworkingDelegate
}

public protocol NetworkingFactory {
    func makeNetworking() -> Networking
}

class CoreNetworkingDelegateMock: NetworkingDelegate {
    func set(apiService: APIService) { }
    func onLogout() { }

    func onForceUpgrade(message: String) { }

    var responseDelegateForLoginAndSignup: HumanVerifyResponseDelegate?
    var paymentDelegateForLoginAndSignup: HumanVerifyPaymentDelegate?
    func onHumanVerify(parameters: HumanVerifyParameters, currentURL: URL?, completion: @escaping ((HumanVerifyFinishReason) -> Void)) { }
    func onDeviceVerify(parameters: DeviceVerifyParameters) -> String? { nil }
    func getSupportURL() -> URL { URL(string: "")! }
}

public enum CoreNetworkingDelegateKey: TestDependencyKey {
    public static var testValue: NetworkingDelegate {
        CoreNetworkingDelegateMock()
    }
}

extension DependencyValues {
    public var networkingDelegate: NetworkingDelegate {
        get { self[CoreNetworkingDelegateKey.self] }
        set { self[CoreNetworkingDelegateKey.self] = newValue }
    }
}
