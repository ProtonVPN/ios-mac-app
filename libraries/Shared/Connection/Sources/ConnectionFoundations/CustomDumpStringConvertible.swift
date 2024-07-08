//
//  Created on 01/07/2024.
//
//  Copyright (c) 2024 Proton AG
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

import Foundation
import CustomDump
import Ergonomics
import struct Domain.Server
import struct Domain.VPNConnectionFeatures
import struct VPNShared.VpnCertificate

// For now, let's override the dump descriptions with minimal info so `_printChanges` reducer is easier to read
extension Domain.Server: CustomDumpStringConvertible {
    public var customDumpDescription: String {
        return "Server(name: \(logical.name))"
    }
}

extension Domain.VPNConnectionFeatures: CustomDumpStringConvertible {
    public var customDumpDescription: String {
        return "VPNConnectionFeatures"
    }
}

extension VPNKeys: CustomDumpStringConvertible {
    public var customDumpDescription: String {
        return "VPNKeys"
    }
}

extension VpnCertificate: CustomDumpStringConvertible {
    public var customDumpDescription: String {
        return "VPNCertificate(validUntil: \(validUntil))"
    }
}

extension PrivateKey: CustomDumpStringConvertible {
    public var customDumpDescription: String {
        #if DEBUG
        return "PrivateKey(fingerprint: \(rawRepresentation.fingerprint))"
        #else
        return "PrivateKey"
        #endif
    }
}

extension PublicKey: CustomDumpStringConvertible {
    public var customDumpDescription: String {
        #if DEBUG
        return "PublicKey(fingerprint: \(rawRepresentation.fingerprint))"
        #else
        return "PublicKey"
        #endif
    }
}
