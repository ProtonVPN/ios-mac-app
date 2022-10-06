//
//  VpnAuthenticationKeychain.swift
//  vpncore - Created on 16.04.2021.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation

public protocol VpnAuthenticationStorageFactory {
    func makeVpnAuthenticationStorage() -> VpnAuthenticationStorage
}

public protocol VpnAuthenticationStorage: AnyObject {
    func deleteKeys()
    func deleteCertificate()
    func getKeys() -> VpnKeys
    func getStoredCertificate() -> VpnCertificate?
    func getStoredCertificateFeatures() -> VPNConnectionFeatures?
    func getStoredKeys() -> VpnKeys?
    func store(keys: VpnKeys)
    func store(certificate: VpnCertificateWithFeatures)
    var delegate: VpnAuthenticationStorageDelegate? { get set }
}

public protocol VpnAuthenticationStorageDelegate: AnyObject {
    func certificateDeleted()
    func certificateStored(_ certificate: VpnCertificateWithFeatures)
}

public protocol VpnAuthenticationStorageUserDefaults {
    var vpnCertificateFeatures: VPNConnectionFeatures? { get set }
}
