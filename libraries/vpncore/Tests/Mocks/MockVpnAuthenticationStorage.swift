//
//  Created on 2022-04-21.
//
//  Copyright (c) 2022 Proton AG
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

class MockVpnAuthenticationStorage: VpnAuthenticationStorage {
    public var certAndFeaturesStored: ((VpnCertificateWithFeatures) -> ())?
    public var keysStored: ((VpnKeys) -> ())?

    var keys: VpnKeys?
    var cert: VpnCertificate?
    var features: VPNConnectionFeatures?

    func deleteKeys() {
        keys = nil
        deleteCertificate()
    }

    func deleteCertificate() {
        cert = nil
        delegate?.certificateDeleted()
    }

    func getKeys() -> VpnKeys {
        if let keys = keys {
            return keys
        }

        let keys = VpnKeys()
        self.store(keys: keys)
        return keys
    }

    func getStoredCertificate() -> VpnCertificate? {
        cert
    }

    func getStoredCertificateFeatures() -> VPNConnectionFeatures? {
        features
    }

    func getStoredKeys() -> VpnKeys? {
        keys
    }

    func store(keys: VpnKeys) {
        self.keys = keys
        keysStored?(keys)
    }

    func store(certificate: VpnCertificateWithFeatures) {
        self.cert = certificate.certificate
        self.features = certificate.features
        delegate?.certificateStored(certificate)
        certAndFeaturesStored?(certificate)
    }

    var delegate: VpnAuthenticationStorageDelegate?
}
