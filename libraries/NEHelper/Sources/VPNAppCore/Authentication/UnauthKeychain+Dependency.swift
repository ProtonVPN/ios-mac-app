//
//  Created on 02/05/2024.
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
import Dependencies

public struct UnauthKeychainHandleDependencyKey: DependencyKey {
    public static let liveValue: UnauthKeychainHandle = UnauthKeychain.default
    public static let testValue = liveValue
}

extension DependencyValues {
    public var unauthKeychain: UnauthKeychainHandle {
        get { self[UnauthKeychainHandleDependencyKey.self] }
        set { self[UnauthKeychainHandleDependencyKey.self] = newValue }
    }
}

