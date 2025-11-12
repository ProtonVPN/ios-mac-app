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

import Domain
import Foundation

#if DEBUG
    public class MockVpnAuthenticationStorage: VpnAuthenticationStorageSync {
        public var certAndFeaturesStored: ((VpnCertificateWithFeatures) -> Void)?
        public var keysStored: ((VpnKeys) -> Void)?
        public var certDeleted: (() -> Void)?
        public var keysDeleted: (() -> Void)?

        public var keys: VpnKeys?
        public var cert: VpnCertificate?
        public var features: VPNConnectionFeatures?

        private let eventsContinuation: AsyncStream<VpnAuthenticationStorageEvent>.Continuation
        public let events: AsyncStream<VpnAuthenticationStorageEvent>

        public init() {
            let (stream, continuation) = AsyncStream.makeStream(of: VpnAuthenticationStorageEvent.self)
            self.events = stream
            self.eventsContinuation = continuation
        }

        public func deleteKeys() {
            keys = nil
            deleteCertificate()
            keysDeleted?()
        }

        public func deleteCertificate() {
            cert = nil
            certDeleted?()
            eventsContinuation.yield(.certificateDeleted)
        }

        public func getKeys() -> VpnKeys {
            if let keys {
                return keys
            }

            let newKeys = VpnKeys.mock()
            store(keys: newKeys)
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
            cert = certificate.certificate
            features = certificate.features
            eventsContinuation.yield(.certificateStored(certificate.certificate))
            certAndFeaturesStored?(certificate)
        }

        public func store(_ certificate: VpnCertificate) {
            cert = certificate
            eventsContinuation.yield(.certificateStored(certificate))
        }
    }

    public extension MockVpnAuthenticationStorage {
        func with(keys: VpnKeys) -> Self {
            store(keys: keys)
            return self
        }
    }
#endif
