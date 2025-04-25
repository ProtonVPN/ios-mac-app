//
//  Created on 24/04/2025 by adam.
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

import Testing
@testable import Hermes

@Test
func modelValidation() throws {
    do { _ = try HermesResolver(ipAddress: "") }
    catch { #expect(error == .invalidIPAddress) }

    #expect(HermesResolver.proton.location == "10.2.0.1")

    let uniqueResolvers: Set<HermesResolver> = [.proton, .cloudFlare, .proton, .google]
    #expect(uniqueResolvers.count == 3)
}
