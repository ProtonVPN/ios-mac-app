//
//  Created on 11/11/2025 by Max Kupetskyi.
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

public struct WireguardMacLogProvider {
    public var logs: (@escaping (String?) -> Void) -> Void
}

extension WireguardMacLogProvider: NetworkExtensionLogProvider {
    public func logs(completion: @escaping (String?) -> Void) {
        logs(completion)
    }
}

extension WireguardMacLogProvider: DependencyKey {
    public static var liveValue: WireguardMacLogProvider = .init(logs: { completion in
        @Dependency(\.xpcConnectionsRepository) var xpcConnectionsRepository

        xpcConnectionsRepository.getXpcConnection(for: SystemExtensionType.wireGuard.machServiceName).getLogs { logsData in
            guard let data = logsData, let logs = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            completion(logs)
        }
    })
}

extension WireguardMacLogProvider: TestDependencyKey {
    public static var testValue: WireguardMacLogProvider = .init(logs: { _ in })
}

public extension DependencyValues {
    var wireguardMacLogProvider: WireguardMacLogProvider {
        get { self[WireguardMacLogProvider.self] }
        set { self[WireguardMacLogProvider.self] = newValue }
    }
}

private struct UnimplementedXPCConnectionsRepository: XPCConnectionsRepository {
    func getXpcConnection(for _: String) -> XPCServiceUser {
        fatalError("\(Self.self).getXpcConnection must be implemented for tests")
    }
}
