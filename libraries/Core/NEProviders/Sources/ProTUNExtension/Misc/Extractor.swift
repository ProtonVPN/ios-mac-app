//
//  Created on 07/01/2026 by adam.
//
//  Copyright (c) 2026 Proton AG
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

import Domain
import Foundation

enum TunnelDataExtractor {
    enum Error: Swift.Error {
        case noVendorData
        case noProTUNData
    }

    private static let decoder = JSONDecoder()

    static func data(from options: [String: Any]?) throws -> ProTUNMinimalData {
        let protunData = try getProTUNData(options)
        return try decoder.decode(ProTUNMinimalData.self, from: protunData)
    }

    private static func getProTUNData(_ options: [String: Any]?) throws(Error) -> Data {
        guard let vendorData = options?["VendorData"] as? [String: Any] else {
            throw .noVendorData
        }
        guard let protunData = vendorData["ProTUN"] as? Data else {
            throw .noProTUNData
        }
        return protunData
    }
}
