//
//  NativeClient.swift
//  vpncore - Created on 27.04.2021.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
import GoLibs

protocol LocalAgentNativeClientImplementationDelegate: AnyObject {
    func didReceiveError(code: Int)
    func didChangeState(state: LocalAgentState?)
    func didReceiveConnectionDetails(_ details: ConnectionDetailsMessage)
    func didReceiveFeatureStatistics(_ statistics: FeatureStatisticsMessage)
}

final class LocalAgentNativeClientImplementation: NSObject, LocalAgentNativeClientProtocol {

    func onTlsSessionEnded() {

    }

    func onTlsSessionStarted() {

    }

    weak var delegate: LocalAgentNativeClientImplementationDelegate?

    func log(_ text: String?) {
        guard let text = text else {
            return
        }

        LegacyCommon.log.info("\(text)", category: .localAgent, event: .log)
    }

    func onError(_ code: Int, description: String?) {
        LegacyCommon.log.error("Received error \(code): \(description ?? "(empty)") from local agent shared library", category: .localAgent, event: .error)
        delegate?.didReceiveError(code: code)
    }

    func onState(_ state: String?) {
        guard let state = state else {
            LegacyCommon.log.error("Received empty state from local agent shared library", category: .localAgent, event: .stateChange)
            return
        }
        
        LegacyCommon.log.info("Local agent shared library state reported as changed to \(state)", category: .localAgent, event: .stateChange)
        delegate?.didChangeState(state: LocalAgentState.from(string: state))
    }

    func onStatusUpdate(_ status: LocalAgentStatusMessage?) {
        if let details = status?.connectionDetails {
            didReceive(connectionDetails: details)
        }

        if let statistics = status?.featuresStatistics {
            didReceive(statistics: statistics)
        }
    }

    private func didReceive(connectionDetails: LocalAgentConnectionDetails) {
        let detailsMessage = ConnectionDetailsMessage(details: connectionDetails)
        LegacyCommon.log.info("Local agent shared library received connection details: \("\(detailsMessage)".maskIPs)", category: .localAgent, event: .connect)
        delegate?.didReceiveConnectionDetails(detailsMessage)
    }

    private func didReceive(statistics: LocalAgentStringToValueMap) {
        do {
            let stats = try FeatureStatisticsMessage(localAgentStatsDictionary: statistics)
            LegacyCommon.log.info("Local agent shared library received statistics: \(stats)", category: .localAgent, event: .stateChange)
            delegate?.didReceiveFeatureStatistics(stats)
        } catch {
            LegacyCommon.log.error("Failed to decode feature stats", category: .localAgent, event: .error, metadata: ["error": "\(error)"])
        }
    }
}
