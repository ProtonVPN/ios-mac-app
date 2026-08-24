//
//  Created on 11/08/2026.
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
import Foundation
import Localization

/// The language the API session sends as `x-pm-locale`, so the backend's translated names arrive in the language the
/// user chose for the app.
public enum AppLanguageKey: DependencyKey {
    public static let liveValue: @Sendable () -> String = {
        LocalizationUtility.default.preferredLanguageCode
    }

    public static let testValue: @Sendable () -> String = { "en" }
}

public extension DependencyValues {
    var appLanguage: @Sendable () -> String {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}
