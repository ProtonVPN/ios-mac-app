//
//  Created on 2025-11-27 by Pawel Jurczyk.
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

import Foundation

import Dependencies
import DependenciesMacros

import Connection
import Domain
import VPNAppCore

/// Collects information about connection status updates, upsell, onboarding and user in app settings.
/// Triggers reporting of the events to Telemetry (if user opted in) and Business endpoint (if business flag is on).
@DependencyClient
public struct TelemetryService {
    public var onboardingEvent: (_ event: OnboardingEvent.Event) async throws -> Void
    public var upsellEvent: (
        _ event: UpsellEvent.Event,
        _ modalSource: UpsellModalSource?,
        _ newPlanName: String?,
        _ offerReference: String?,
        _ flowType: UpsellEvent.FlowType?
    ) async throws -> Void
    public var startSettingsHeartbeat: () -> Void

    public var vpnGatewayConnectionChanged: (_ connectionStatus: ConnectionStatus) async throws -> Void
    public var connectionStateChanged: (_ connectionState: ConnectionState) async throws -> Void
    public var userInitiatedVPNChange: (_ change: UserInitiatedVPNChange) async -> Void
    public var reachabilityChanged: (_ networkType: ConnectionDimensions.NetworkType) async -> Void
}
