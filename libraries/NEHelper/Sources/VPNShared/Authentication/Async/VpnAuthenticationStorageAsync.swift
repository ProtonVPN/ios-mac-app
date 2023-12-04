//
//  Created on 04/12/2023.
//
//  Copyright (c) 2023 Proton AG
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

public protocol VpnAuthenticationStorageAsync: AnyObject {
    func deleteKeys() async
    func deleteCertificate() async
    func getKeys() async -> VpnKeys
    func getStoredCertificate() async -> VpnCertificate?
    func getStoredCertificateFeatures() -> VPNConnectionFeatures?
    func getStoredKeys() async -> VpnKeys?
    func store(keys: VpnKeys) async
    func store(_ certificate: VpnCertificate) async
    func store(_ certificate: VpnCertificateWithFeatures) async

    var delegate: VpnAuthenticationStorageDelegate? { get set }
}
