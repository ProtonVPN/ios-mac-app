//
//  NativeClient.swift
//  vpncore - Created on 27.04.2021.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
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
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
import WireguardSRP

protocol LocalAgentNativeClientImplementationDelegate: AnyObject {
    func didReceiveError(code: Int)
    func didChangeState(state: LocalAgentState?)
}

final class LocalAgentNativeClientImplementation: NSObject, LocalAgentNativeClientProtocol {
    func onStatusUpdate(_ status: LocalAgentStatusMessage?) { }

    weak var delegate: LocalAgentNativeClientImplementationDelegate?

    func log(_ text: String?) {
        guard let text = text else {
            return
        }

        vpncore.log.info("\(text)", category: .localAgent, event: .log)
    }

    func onError(_ code: Int, description: String?) {
        vpncore.log.error("Received error \(code): \(description ?? "(empty)") from local agent shared library", category: .localAgent, event: .error)
        delegate?.didReceiveError(code: code)
    }

    func onState(_ state: String?) {
        guard let state = state else {
            vpncore.log.error("Received empty state from local agent shared library", category: .localAgent, event: .stateChange)
            return
        }
        
        vpncore.log.info("Local agent shared library state reported as changed to \(state)", category: .localAgent, event: .stateChange)
        delegate?.didChangeState(state: LocalAgentState.from(string: state))
    }
}
