//
//  Created on 2022-05-26.
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
import LegacyCommon

// Overriden to make use of XPC connection, available only on macOS.
class OpenVpnMacProtocolFactory: OpenVpnProtocolFactory {
    public typealias Factory = PropertiesManagerFactory &
                                XPCConnectionsRepositoryFactory &
                                NETunnelProviderManagerWrapperFactory

    private let xpcConnectionsRepository: XPCConnectionsRepository

    public init(bundleId: String,
                appGroup: String,
                factory: Factory) {
        self.xpcConnectionsRepository = factory.makeXPCConnectionsRepository()
        super.init(bundleId: bundleId,
                   appGroup: appGroup,
                   propertiesManager: factory.makePropertiesManager(),
                   vpnManagerFactory: factory)
    }

    override public func logs(completion: @escaping (String?) -> Void) {
        xpcConnectionsRepository.getXpcConnection(for: SystemExtensionType.openVPN.machServiceName).getLogs { logsData in
            guard let data = logsData, let logs = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            completion(logs)
        }
    }

}
