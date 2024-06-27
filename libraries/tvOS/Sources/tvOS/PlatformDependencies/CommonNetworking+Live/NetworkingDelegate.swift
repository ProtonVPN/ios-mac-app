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
import protocol ProtonCoreServices.APIService
import protocol ProtonCoreServices.HumanVerifyResponseDelegate
import protocol ProtonCoreServices.HumanVerifyPaymentDelegate
import struct ProtonCoreNetworking.HumanVerifyParameters
import struct ProtonCoreNetworking.DeviceVerifyParameters
import enum ProtonCoreServices.HumanVerifyFinishReason

import CommonNetworking

class TVOSNetworkingDelegate: NetworkingDelegate {
    func set(apiService: APIService) { }

    func onLogout() { }
    func onForceUpgrade(message: String) { }

    var responseDelegateForLoginAndSignup: HumanVerifyResponseDelegate?
    var paymentDelegateForLoginAndSignup: HumanVerifyPaymentDelegate?
    func onHumanVerify(parameters: HumanVerifyParameters, currentURL: URL?, completion: @escaping ((HumanVerifyFinishReason) -> Void)) { }
    func onDeviceVerify(parameters: DeviceVerifyParameters) -> String? { nil }
    func getSupportURL() -> URL { URL(string: "")! }
}

extension CoreNetworkingDelegateKey: DependencyKey {
    public static let liveValue: NetworkingDelegate = TVOSNetworkingDelegate()
}
