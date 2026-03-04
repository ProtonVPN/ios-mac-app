//
//  Created on 03/03/2026 by adam.
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

// A Result like type, heavily constrained to be mainly `Codable`
public enum CodableResult<Success: Codable, Failure: Codable>: Codable {
    case success(Success)
    case failure(Failure)
}

extension CodableResult: Sendable where Success: Sendable, Failure: Sendable {}
extension CodableResult: Equatable where Success: Equatable, Failure: Equatable {}
