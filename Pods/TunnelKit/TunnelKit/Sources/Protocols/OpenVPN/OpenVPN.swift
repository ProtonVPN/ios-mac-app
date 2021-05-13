//
//  OpenVPN.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 5/19/19.
//  Copyright (c) 2021 Davide De Rosa. All rights reserved.
//
//  https://github.com/passepartoutvpn
//
//  This file is part of TunnelKit.
//
//  TunnelKit is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  TunnelKit is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with TunnelKit.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import __TunnelKitCore
import __TunnelKitOpenVPN

/// Container for OpenVPN classes.
public class OpenVPN {

    /**
     Initializes the PRNG. Must be issued before using `OpenVPNSession`.
     
     - Parameter seedLength: The length in bytes of the pseudorandom seed that will feed the PRNG.
     */
    public static func prepareRandomNumberGenerator(seedLength: Int) -> Bool {
        let seed: ZeroingData
        do {
            seed = try SecureRandom.safeData(length: seedLength)
        } catch {
            return false
        }
        return CryptoBox.preparePRNG(withSeed: seed.bytes, length: seed.count)
    }
    
}
