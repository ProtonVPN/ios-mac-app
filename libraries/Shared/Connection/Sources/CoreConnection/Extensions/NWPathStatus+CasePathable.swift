//
//  Created on 24/07/2025 by Chris Janusiewicz.
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

import CasePaths
import struct Network.NWPath

extension NWPath.Status: @retroactive CasePathable {
    public struct AllCasePaths {
        public var satisfied: AnyCasePath<NWPath.Status, Void> {
            AnyCasePath(
                embed: { NWPath.Status.satisfied },
                extract: { guard case .satisfied = $0 else { return nil } }
            )
        }

        public var unsatisfied: AnyCasePath<NWPath.Status, Void> {
            AnyCasePath(
                embed: { NWPath.Status.unsatisfied },
                extract: { guard case .unsatisfied = $0 else { return nil } }
            )
        }

        public var requiresConnection: AnyCasePath<NWPath.Status, Void> {
            AnyCasePath(
                embed: { NWPath.Status.requiresConnection },
                extract: { guard case .requiresConnection = $0 else { return nil } }
            )
        }
    }

    public static let allCasePaths: AllCasePaths = .init()
}
