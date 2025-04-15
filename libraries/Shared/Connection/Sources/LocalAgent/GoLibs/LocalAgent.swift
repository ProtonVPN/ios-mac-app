//
//  Created on 03/06/2024.
//
//  Copyright (c) 2024 Proton AG
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

import CasePaths
import Dependencies

import class GoLibs.LocalAgentFeatures
import protocol GoLibs.LocalAgentNativeClientProtocol

import CoreConnection
import Domain

protocol LocalAgent {
    func createEventStream() -> AsyncStream<LocalAgentEvent>

    func connect(configuration: ConnectionConfiguration, data: VPNAuthenticationData) throws(LAConnectionCreationError)
    func set(features: LocalAgentFeatures)
    func disconnect()

    var netShieldType: NetShieldType { get }

    func retrieveNetShieldStats()
}

@DebugDescription
@CasePathable
public enum LocalAgentEvent: Sendable {
    case error(LocalAgentError)
    case state(LocalAgentState)
    case features(VPNConnectionFeatures)
    case connectionDetails(ConnectionDetailsMessage)
    case stats(FeatureStatisticsMessage)
}

struct LocalAgentKey: DependencyKey {
    #if targetEnvironment(simulator)
        static let liveValue: LocalAgent = LocalAgentMock(state: .disconnected)
    #else
        static let liveValue: LocalAgent = LocalAgentImplementation()
    #endif
}

extension DependencyValues {
    var localAgent: LocalAgent {
        get { self[LocalAgentKey.self] }
        set { self[LocalAgentKey.self] = newValue }
    }
}

package extension NetShieldType {
    var shouldObserveNetShieldStats: Bool {
        switch self {
        case .off, .level1:
            false
        case .level2:
            true
        }
    }
}

extension LocalAgentEvent: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .error(let localAgentError):
            return ".error(\(localAgentError))"
        case .state(let localAgentState):
            return ".state(\(localAgentState))"
        case .features(let features):
            return ".features(\(features))"
        case .connectionDetails(let connectionDetailsMessage):
            return ".connectionDetails(\(connectionDetailsMessage))"
        case .stats(let featureStatisticsMessage):
            return ".stats(\(featureStatisticsMessage))"
        }
    }
}
