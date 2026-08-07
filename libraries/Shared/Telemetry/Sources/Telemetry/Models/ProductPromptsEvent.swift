//
//  Created on 2026-07-31 by Pawel Jurczyk.
//
//  Copyright (c) 2026 Proton AG
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

import Dependencies
import Domain
import Foundation
import Sharing

public struct ProductPromptsEvent: TelemetryEvent, Encodable {
    public let measurementGroup: String = "vpn.any.product_prompts"
    public let event: Event
    public let dimensions: Dimensions

    @SharedReader(.successfulConnectionsSinceLastPrompt) var successfulConnectionsSinceLastPrompt
    @SharedReader(.whenLastReviewShown) var reviewTimestamp

    public enum Event: String, Encodable {
        case ratingBoosterPromptRequested = "rating_booster_prompt_requested"
    }

    public struct Dimensions: Encodable {
        public enum CodingKeys: String, CodingKey {
            case userCountry = "user_country"
            case userTier = "user_tier"
        }

        public let userCountry: String
        public let userTier: CommonTelemetryDimensions.UserTier
    }

    public var values: Values {
        let daysSinceLastPrompt = reviewTimestamp.flatMap {
            @Dependency(\.calendar) var calendar
            @Dependency(\.date) var date
            return calendar.dateComponents([.day], from: $0, to: date.now).day
        } ?? 0
        return Values(
            connectionsSinceLastPrompt: successfulConnectionsSinceLastPrompt,
            daysSinceLastPrompt: daysSinceLastPrompt
        )
    }

    public struct Values: Encodable {
        public enum CodingKeys: String, CodingKey {
            case connectionsSinceLastPrompt = "connections_since_last_prompt"
            case daysSinceLastPrompt = "days_since_last_prompt"
        }

        public let connectionsSinceLastPrompt: Int
        public let daysSinceLastPrompt: Int
    }

    init() {
        @SharedReader(.userLocation) var userLocation
        let dimensions = ProductPromptsEvent.Dimensions(
            userCountry: userLocation?.location.country.lowercased() ?? "n/a",
            userTier: .readFromKeychain()
        )

        self.event = .ratingBoosterPromptRequested
        self.dimensions = dimensions
    }
}

extension ProductPromptsEvent: CustomDebugStringConvertible {
    public var debugDescription: String {
        "| measurementGroup: \(measurementGroup) | event: \(event) | dimensions: \(dimensions) | values: \(values) |"
    }
}

extension ProductPromptsEvent.Dimensions: CustomDebugStringConvertible {
    public var debugDescription: String {
        "| userCountry: \(userCountry) | userTier: \(userTier) |"
    }
}

extension ProductPromptsEvent.Values: CustomDebugStringConvertible {
    public var debugDescription: String {
        "| connectionsSinceLastPrompt: \(connectionsSinceLastPrompt) | daysSinceLastPrompt: \(daysSinceLastPrompt) |"
    }
}
