//
//  Created on 18/08/2025 by Shahin Katebi.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Dependencies
import Domain
import Foundation
import LegacyCommon
import PMLogger

public struct PlutoniumMacLogProvider {
    public var logs: (@escaping (String?) -> Void) -> Void
}

extension PlutoniumMacLogProvider: NetworkExtensionLogProvider {
    public func logs(completion: @escaping (String?) -> Void) {
        logs(completion)
    }
}

// MARK: - TCA Dependency

extension PlutoniumMacLogProvider: DependencyKey {
    public static var liveValue: PlutoniumMacLogProvider = .init(logs: { completion in
        @Dependency(\.xpcConnectionsRepository) var xpcConnectionsRepository
        guard VPNFeatureFlagType.plutoniumMacOS.enabled else {
            completion(nil)
            return
        }

        let xpcConnection = xpcConnectionsRepository.getXpcConnection(
            for: SystemExtensionType.plutonium.machServiceName
        )
        xpcConnection.getLogs { data in
            let logContent = data.flatMap { String(data: $0, encoding: .utf8) }
            completion(logContent)
        }
    })
}

extension PlutoniumMacLogProvider: TestDependencyKey {
    public static var testValue: PlutoniumMacLogProvider = .init(logs: { _ in })
}

public extension DependencyValues {
    var plutoniumMacLogProvider: PlutoniumMacLogProvider {
        get { self[PlutoniumMacLogProvider.self] }
        set { self[PlutoniumMacLogProvider.self] = newValue }
    }
}
