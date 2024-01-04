//
//  VpnProtocolChangeManagerMock.swift
//  ProtonVPN - Created on 2021-04-19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Foundation

import Domain
import VPNShared
import LegacyCommon

@testable import ProtonVPN

class VpnProtocolChangeManagerMock: VpnProtocolChangeManager {
    var protocolChanged: ((VpnProtocol) -> Void)?

    func change(toProtocol: VpnProtocol, userInitiated: Bool, completion: @escaping (Result<(), Error>) -> Void) {
        protocolChanged?(toProtocol)
        completion(.success)
    }
}
