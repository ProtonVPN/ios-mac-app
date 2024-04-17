//
//  Created on 23/04/2024.
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

struct NetworkClient {
    func fetchSignInCode() async throws -> String {
        try await Task.sleep(for: .seconds(1))
        return "123 456"
    }

    static var count: Int = 0
    
    func forkSession() async throws -> String {
        for attempt in 1...5 {
            print("poll API... \(attempt)")
            try await Task.sleep(for: .seconds(1))
        }
        Self.count += 1
        return "tv user\(Self.count)"
    }
}
