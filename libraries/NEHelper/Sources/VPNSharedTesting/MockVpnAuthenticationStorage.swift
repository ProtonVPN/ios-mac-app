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
import VPNShared

public class MockVpnAuthenticationStorage: VpnAuthenticationStorageSync {
    public var certAndFeaturesStored: ((VpnCertificateWithFeatures) -> ())?
    public var keysStored: ((VpnKeys) -> ())?
    public var certDeleted: (() -> Void)?

    public var keys: VpnKeys?
    public var cert: VpnCertificate?
    public var features: VPNConnectionFeatures?
    
    public init() { }

    public func deleteKeys() {
        keys = nil
        deleteCertificate()
    }

    public func deleteCertificate() {
        cert = nil
        certDeleted?()
        delegate?.certificateDeleted()
    }

    public func getKeys() -> VpnKeys {
        if let keys = keys {
            return keys
        }

        let newKeys = VpnKeys.mock()
        self.store(keys: newKeys)
        return newKeys
    }

    public func getStoredCertificate() -> VpnCertificate? {
        cert
    }

    public func getStoredCertificateFeatures() -> VPNConnectionFeatures? {
        features
    }

    public func getStoredKeys() -> VpnKeys? {
        keys
    }

    public func store(keys: VpnKeys) {
        self.keys = keys
        keysStored?(keys)
    }

    public func store(_ certificate: VpnCertificateWithFeatures) {
        self.cert = certificate.certificate
        self.features = certificate.features
        delegate?.certificateStored(certificate.certificate)
        certAndFeaturesStored?(certificate)
    }

    public func store(_ certificate: VpnCertificate) {
        self.cert = certificate
        delegate?.certificateStored(certificate)
    }

    public var delegate: VpnAuthenticationStorageDelegate?
}
