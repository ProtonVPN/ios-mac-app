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

import protocol GoLibs.LocalAgentNativeClientProtocol

import ConnectionFoundations
import Domain
import Ergonomics

#if swift(>=6.0)
#warning("Improve LocalAgent in order to generalize createEventStream() to return an AsyncSequence<LocalAgentEvent>")
#endif
protocol LocalAgent {
    var state: LocalAgentState { get throws }
    func createEventStream() -> AsyncThrowingStream<LocalAgentEvent, Error>
    func connect(configuration: ConnectionConfiguration, data: VPNAuthenticationData) throws
    func disconnect()
}

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
