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

open class TelemetrySettings {

    public typealias Factory = PropertiesManagerFactory & VpnKeychainFactory
    private let factory: Factory

    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()

    public init(_ factory: Factory) {
        self.factory = factory
    }

    public var telemetryUsageData: Bool {
        propertiesManager.getTelemetryUsageData()
    }

    public var businessEvents: Bool {
        (try? vpnKeychain.fetchCached())?.businessEvents == true
    }

    public func updateTelemetryUsageData(isOn: Bool) {
        Task { await propertiesManager.setTelemetryUsageData(enabled: isOn) }
    }

    public var telemetryCrashReports: Bool {
        propertiesManager.getTelemetryCrashReports()
    }

    public func updateTelemetryCrashReports(isOn: Bool) {
        propertiesManager.setTelemetryCrashReports(enabled: isOn)
    }
}
