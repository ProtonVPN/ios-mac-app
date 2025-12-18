//
//  Created on 18/12/2025 by Chris Janusiewicz.
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

import Dependencies
import Foundation
import Hermes
import Sharing

extension HermesClient: @retroactive DependencyKey {
    private static func reportFailure<T>(with result: T) -> T {
        log.assertionFailure("Hermes disabled")
        return result
    }

    public static let liveValue = HermesClient(
        isEnabled: { SharedReader(value: false) },
        setIsEnabled: { _ in },
        activeHermesResolvers: { Self.reportFailure(with: SharedReader(value: [])) },
        validateHermesLocation: { _ in Self.reportFailure(with: false) },
        addHermesResolver: { _ in Self.reportFailure(with: false) },
        removeHermesResolver: { _ in Self.reportFailure(with: false) },
        applyDiff: { _ in }
    )
}
