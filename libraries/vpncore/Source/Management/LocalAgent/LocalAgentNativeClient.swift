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
import WireguardCrypto

protocol LocalAgentNativeClientDelegate: AnyObject {
    func didReceiveError(code: Int)
    func didChangeState(state: LocalAgentState?)
}

final class LocalAgentNativeClient: NSObject, LocalAgentNativeClientProtocol {
    func onStatusUpdate(_ status: LocalAgentStatusMessage?) { }

    weak var delegate: LocalAgentNativeClientDelegate?

    func log(_ text: String?) {
        guard let text = text else {
            return
        }

        PMLog.D(text)
    }

    func onError(_ code: Int, description: String?) {
        PMLog.D("Received error \(code): \(description ?? "(empty)") from local agent shared library")
        delegate?.didReceiveError(code: code)
    }

    func onState(_ state: String?) {
        guard let state = state else {
            PMLog.ET("Received empty state from local agent shared library")
            return
        }

        PMLog.D("Local agent shared library state reported as changed to \(state)")
        delegate?.didChangeState(state: LocalAgentState.from(string: state))
    }
}
