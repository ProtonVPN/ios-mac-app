//
//  Created on 19/4/24.
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

struct UserSettingsResponse: Codable {
    let code: Int
    let userSettings: UserSettings
}

public struct UserSettings: Codable {
    public let password: Password
    public let twoFactor: TwoFactor

    public init(password: Password,
                twoFactor: TwoFactor) {
        self.password = password
        self.twoFactor = twoFactor
    }

    enum CodingKeys: String, CodingKey {
        case password
        case twoFactor = "_2FA"
    }

    public struct Password: Codable {
        public let mode: PasswordMode

        public enum PasswordMode: Int, Sendable, Codable {
            case singlePassword = 1
            case loginAndMailboxPassword = 2
        }

        enum CodingKeys: String, CodingKey {
            case mode
        }
    }

    public struct TwoFactor: Codable {
        public let type: TwoFactorType

        public enum TwoFactorType: Int, Codable {
            case disabled = 0
            case otp = 1
            case fido2 = 2
            case both = 3
        }

        enum CodingKeys: String, CodingKey {
            case type = "enabled"
        }
    }
}
