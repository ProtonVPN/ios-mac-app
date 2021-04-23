//
//  Keys+Extensions.swift
//  vpncore - Created on 23.04.2021.
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

extension PrivateKey {
    init(rawRepresentation: [UInt8]) {
        let keyPair = Ed25519CreateKeyPair(Data(bytes: rawRepresentation), nil)!
        self.init(keyPair: keyPair)
    }

    init(hex: String) {
        self.init(rawRepresentation: [UInt8](hex.dataFromHex()!))
    }
}

extension PublicKey {
    init(rawRepresentation: [UInt8]) {
        let keyPair = Ed25519CreateKeyPair(nil, Data(bytes: rawRepresentation))!
        self.init(keyPair: keyPair)
    }

    init(hex: String) {
        self.init(rawRepresentation: [UInt8](hex.dataFromHex()!))
    }
}

extension String {
    func dataFromHex() -> Data? {
        let normalized = self.replacingOccurrences(of: ":", with: "")
        guard normalized.count % 2 == 0 else {
            return nil
        }
        var data = Data()
        var byteLiteral = ""
        for (index, character) in normalized.enumerated() {
            if index % 2 == 0 {
                byteLiteral = String(character)
            } else {
                byteLiteral.append(character)
                guard let byte = UInt8(byteLiteral, radix: 16) else { return nil }
                data.append(byte)
            }
        }
        return data
    }
}
