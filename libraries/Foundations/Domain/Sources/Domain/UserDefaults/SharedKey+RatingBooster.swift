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

import Foundation
import Sharing

public extension SharedKey where Self == AppStorageKey<RatingSettings>.Default {
    static var ratingSettings: Self {
        Self[.appStorage("RatingSettings"), default: RatingSettings()]
    }
}

public extension SharedKey where Self == AppStorageKey<Int>.Default {
    static var successfulConnectionsInARow: Self {
        Self[.appStorage("successfulConnectionsInARow"), default: 0]
    }
}

public extension SharedKey where Self == AppStorageKey<Int>.Default {
    static var successfulConnectionsSinceLastPrompt: Self {
        Self[.appStorage("successfulConnectionsSinceLastPrompt"), default: 0]
    }
}

public extension SharedKey where Self == AppStorageKey<Date?>.Default {
    static var whenLastReviewShown: Self {
        Self[.appStorage("whenLastReviewShown"), default: nil]
    }

    static var whenActiveConnectionStarted: Self {
        Self[.appStorage("whenActiveConnectionStarted"), default: nil]
    }

    static var whenFirstSuccessfulConnectionStarted: Self {
        Self[.appStorage("whenFirstSuccessfulConnectionStarted"), default: nil]
    }
}
