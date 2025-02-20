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

extension String {
    init?(intPattern int: Int) {
        let result = withUnsafeBytes(of: int) { bufPtr in
            bufPtr.withMemoryRebound(to: CChar.self) { charBuf -> String? in
                guard let charPtr = charBuf.baseAddress else { return nil }
                return String(cString: charPtr)
            }
        }

        guard let result else { return nil }
        self = result
    }
}

for argument in CommandLine.arguments[1...] {
    guard let intValue = Int(argument), let string = String(intPattern: intValue) else {
        print("Unrecognized or unknown value \(argument)")
        continue
    }
    print("Value: \(string)")
}
