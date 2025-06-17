//
//  VpnKeychainMock.swift
//  vpncore - Created on 26.06.19.
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

#if DEBUG
    import Ergonomics
    import Foundation
    import VPNCrypto

    public class VpnKeychainMock: VpnKeychainProtocol {
        public var didStoreCredentials: ((VpnCredentials) -> Void)?

        public enum KeychainMockError: Error {
            case fetchError
            case getCertificateError
        }

        public var throwsOnFetch: Bool = false

        public static var vpnCredentialsChanged = Notification.Name("vpnCredentialsChanged")
        public static var vpnPlanChanged = Notification.Name("vpnPlanChanged")
        public static var vpnUserDelinquent = Notification.Name("vpnUserDelinquent")

        public var credentials: VpnCredentials?

        public init(planName: String = "free", maxTier: Int = 0) {
            self.credentials = VpnKeychainMock.vpnCredentials(planName: planName, maxTier: maxTier)
        }

        public func fetch() throws -> VpnCredentials {
            if throwsOnFetch {
                throw KeychainMockError.fetchError
            }

            guard let credentials else {
                throw KeychainMockError.fetchError
            }

            return credentials
        }

        public func fetchCached() throws -> CachedVpnCredentials {
            try CachedVpnCredentials(credentials: fetch())
        }

        public func fetchOpenVpnPassword() throws -> Data {
            Data()
        }

        public func storeAndDetectDowngrade(vpnCredentials: VpnCredentials) {
            store(vpnCredentials: vpnCredentials)
        }

        func store(vpnCredentials: VpnCredentials) {
            let newCredentials = vpnCredentials
            let oldCredentials = credentials

            if let oldCredentials {
                if !oldCredentials.isDelinquent, newCredentials.isDelinquent {
                    let downgradeInfo: VpnDowngradeInfo = (oldCredentials, newCredentials)
                    NotificationCenter.default.post(name: Self.vpnUserDelinquent, object: downgradeInfo)
                }
                if oldCredentials.planName != newCredentials.planName {
                    let downgradeInfo: VpnDowngradeInfo = (oldCredentials, newCredentials)
                    NotificationCenter.default.post(name: Self.vpnPlanChanged, object: downgradeInfo)
                }
            }

            credentials = newCredentials

            if oldCredentials != newCredentials {
                NotificationCenter.default.post(name: Self.vpnCredentialsChanged, object: newCredentials)
            }

            didStoreCredentials?(newCredentials)
        }

        public func getServerCertificate() throws -> SecCertificate {
            throw KeychainMockError.getCertificateError
        }

        public func storeServerCertificate() throws {}

        public func clear() {
            credentials = nil
        }

        public func setVpnCredentials(with planName: String, maxTier: Int = 0) {
            credentials = VpnKeychainMock.vpnCredentials(planName: planName, maxTier: maxTier)
        }

        public static func vpnCredentials(planName: String, maxTier: Int) -> VpnCredentials {
            VpnCredentials(
                status: 0,
                planTitle: planName,
                maxConnect: 1,
                maxTier: maxTier,
                services: 0,
                groupId: "grid1",
                name: "username",
                password: "",
                delinquent: 0,
                credit: 0,
                currency: "",
                hasPaymentMethod: false,
                planName: planName,
                subscribed: 0,
                businessEvents: false
            )
        }

        public func hasOldVpnPassword() -> Bool {
            false
        }

        public func clearOldVpnPassword() throws {}

        public func store(wireguardConfiguration _: Data) throws -> Data {
            Data()
        }

        public func fetchWireguardConfigurationReference() throws -> Data {
            Data()
        }

        public func fetchWireguardConfiguration() throws -> String? {
            nil
        }

        public func fetchWidgetPublicKey() throws -> CryptoService.Key {
            throw "Key not found" as GenericError
        }
    }
#endif
