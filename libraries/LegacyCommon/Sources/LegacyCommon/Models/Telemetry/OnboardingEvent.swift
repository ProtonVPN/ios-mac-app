//
//  Created on 15/12/2023.
//
//  Copyright (c) 2023 Proton AG
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

public struct OnboardingEvent: TelemetryEvent, Encodable {

    public let measurementGroup: String = "vpn.any.onboarding"
    public let event: Event
    public let dimensions: Dimensions

    public enum Event: String, Encodable {
        case firstLaunch = "first_launch"
        case signupStart = "signup_start"
        case onboardingStart = "onboarding_start"
        case paymentDone = "payment_done"
        case firstConnection = "first_connection"
    }

    public struct Dimensions: Encodable {
        public enum CodingKeys: String, CodingKey {
            case userCountry = "user_country"
            case userPlan = "user_plan"
        }
        public let userCountry: String
        public let userPlan: String
    }

    public var values: Values { Values() }

    public struct Values: Encodable { }
}
