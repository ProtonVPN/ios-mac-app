//
//  Created on 09/02/2023.
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
import VPNShared

public class TelemetrySettings {

    typealias Factory = PropertiesManagerFactory & AuthKeychainHandleFactory
    private let factory: Factory

    private lazy var authKeychain: AuthKeychainHandle = factory.makeAuthKeychainHandle()
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()

    init(_ factory: Factory) {
        self.factory = factory
    }

    public var telemetryUsageData: Bool {
        guard let username = authKeychain.fetch()?.username,
              let usageData = propertiesManager.getTelemetryUsageData(for: username) else {
            return false
        }
        return usageData
    }

    public func updateTelemetryUsageData(isOn: Bool) {
        guard let username = authKeychain.fetch()?.username else { return }
        propertiesManager.setTelemetryUsageData(for: username, enabled: isOn)
    }

    public var telemetryCrashReports: Bool {
        guard let username = authKeychain.fetch()?.username,
              let usageData = propertiesManager.getTelemetryCrashReports(for: username) else {
            return false
        }
        return usageData
    }

    public func updateTelemetryCrashReports(isOn: Bool) {
        guard let username = authKeychain.fetch()?.username else { return }
        propertiesManager.setTelemetryCrashReports(for: username, enabled: isOn)
    }
}
