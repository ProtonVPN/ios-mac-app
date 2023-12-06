//
//  Created on 06/12/2023.
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

extension VpnAuthenticationKeychain: VpnAuthenticationStorageSync {
    @available(*, noasync, message: "Please use the async version of this method")
    public func deleteKeys() {
        func awaitWithCompletion(_ completion: @escaping () -> Void) {
            Task {
                await deleteKeys()
                completion()
            }
        }
        let group = DispatchGroup()
        group.enter()
        awaitWithCompletion {
            group.leave()
        }
        group.wait()
    }

    @available(*, noasync, message: "Please use the async version of this method")
    public func deleteCertificate() {
        func awaitWithCompletion(_ completion: @escaping () -> Void) {
            Task {
                await deleteCertificate()
                completion()
            }
        }
        let group = DispatchGroup()
        group.enter()
        awaitWithCompletion {
            group.leave()
        }
        group.wait()
    }

    @available(*, noasync, message: "Please use the async version of this method")
    public func getKeys() -> VpnKeys {
        func awaitWithCompletion(_ completion: @escaping (VpnKeys) -> Void) {
            Task { completion(await getKeys()) }
        }
        let group = DispatchGroup()
        group.enter()
        var value: VpnKeys!
        awaitWithCompletion {
            value = $0
            group.leave()
        }
        group.wait()

        return value
    }

    @available(*, noasync, message: "Please use the async version of this method")
    public func store(keys: VpnKeys) {
        func awaitWithCompletion(_ completion: @escaping () -> Void) {
            Task {
                await store(keys: keys)
                completion()
            }
        }
        let group = DispatchGroup()
        group.enter()
        awaitWithCompletion {
            group.leave()
        }
        group.wait()
    }

    @available(*, noasync, message: "Please use the async version of this method")
    public func store(_ certificate: VpnCertificate) {
        func awaitWithCompletion(_ completion: @escaping () -> Void) {
            Task {
                await store(certificate)
                completion()
            }
        }
        let group = DispatchGroup()
        group.enter()
        awaitWithCompletion {
            group.leave()
        }
        group.wait()
    }
    @available(*, noasync, message: "Please use the async version of this method")
    public func store(_ certificate: VpnCertificateWithFeatures) {
        func awaitWithCompletion(_ completion: @escaping () -> Void) {
            Task {
                await store(certificate)
                completion()
            }
        }
        let group = DispatchGroup()
        group.enter()
        awaitWithCompletion {
            group.leave()
        }
        group.wait()
    }

    @available(*, noasync, message: "Please use the async version of this method")
    public func getStoredCertificate() -> VpnCertificate? {
        func awaitWithCompletion(_ completion: @escaping (VpnCertificate?) -> Void) {
            Task { completion(await getStoredCertificate()) }
        }
        let group = DispatchGroup()
        group.enter()
        var value: VpnCertificate?
        awaitWithCompletion {
            value = $0
            group.leave()
        }
        group.wait()

        return value
    }

    @available(*, noasync, message: "Please use the async version of this method")
    public func getStoredKeys() -> VpnKeys? {
        func awaitWithCompletion(_ completion: @escaping (VpnKeys?) -> Void) {
            Task { completion(await getStoredKeys()) }
        }
        let group = DispatchGroup()
        group.enter()
        var value: VpnKeys?
        awaitWithCompletion {
            value = $0
            group.leave()
        }
        group.wait()

        return value
    }
}
