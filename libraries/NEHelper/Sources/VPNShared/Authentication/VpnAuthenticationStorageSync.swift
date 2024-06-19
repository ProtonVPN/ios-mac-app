//
//  VpnAuthenticationKeychain.swift
//  vpncore - Created on 16.04.2021.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
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
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
import Dependencies
import Domain

public protocol VpnAuthenticationStorageFactory {
    func makeVpnAuthenticationStorage() -> VpnAuthenticationStorageSync
}

public protocol VpnAuthenticationStorageSync {
    func deleteKeys()
    func deleteCertificate()
    func getKeys() -> VpnKeys
    func getStoredCertificate() -> VpnCertificate?
    func getStoredKeys() -> VpnKeys?
    func store(keys: VpnKeys)
    func store(_ certificate: VpnCertificate)
    func store(_ certificate: VpnCertificateWithFeatures)
    func getStoredCertificateFeatures() -> VPNConnectionFeatures?

    var delegate: VpnAuthenticationStorageDelegate? { get set }
}

public protocol VpnAuthenticationStorageDelegate: AnyObject {
    func certificateDeleted()
    func certificateStored(_ certificate: VpnCertificate)
}

public protocol VpnAuthenticationStorageUserDefaults {
    var vpnCertificateFeatures: VPNConnectionFeatures? { get set }
}

public enum VPNAuthenticationStorageConfigKey: TestDependencyKey {
    public static let testValue: String = "test.prt.ProtonVPN"
}

public enum VPNAuthenticationStorageKey: DependencyKey {
    public static let liveValue: VpnAuthenticationStorageSync = VpnAuthenticationKeychain()
}

extension DependencyValues {
    public var vpnAuthenticationStorage: VpnAuthenticationStorageSync {
        get { self[VPNAuthenticationStorageKey.self] }
        set { self[VPNAuthenticationStorageKey.self] = newValue }
    }

    public var vpnAuthenticationStorageConfig: String {
        get { self[VPNAuthenticationStorageConfigKey.self] }
        set { self[VPNAuthenticationStorageConfigKey.self] = newValue }
    }
}
