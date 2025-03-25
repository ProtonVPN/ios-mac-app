//
//  Created on 20.02.2025.
//
//  Copyright (c) 2025 Proton AG
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

/**
 Run this in your terminal by navigating to `libraries/Foundation/Domain` and running `swift run errordecoder <value>`.
*/

extension String {
    init?(charCode: FourCharCode) {
        let result = withUnsafeBytes(of: charCode.littleEndian) { bufPtr in
            let data = Data(bytes: bufPtr.baseAddress!, count: MemoryLayout<FourCharCode>.size)
            return String(data: data, encoding: .ascii)
        }

        guard let result else { return nil }
        self = result
    }
}

for var argument in CommandLine.arguments[1...] {
    var hex = false

    if argument.hasPrefix("0x") {
        hex = true
        argument.removeFirst(2)
    }

    guard let codeValue = FourCharCode(argument, radix: hex ? 16 : 10), let string = String(charCode: codeValue) else {
        print("Unrecognized or unknown value \(argument)")
        continue
    }
    print("Value: \(string)")
}
