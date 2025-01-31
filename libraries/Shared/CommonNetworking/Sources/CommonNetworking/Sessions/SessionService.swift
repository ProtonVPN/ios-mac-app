//
//  Created on 20/06/2024.
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
import Domain

public struct SessionService: TestDependencyKey {
    public var selector: () async throws -> String
    public var sessionCookie: () -> HTTPCookie?
    public var getUpgradePlanSession: (String) async -> String
    public var getExtensionSessionSelector: (AppContext) async throws -> String

    public init(
        selector: @escaping () async throws -> String,
        sessionCookie: @escaping () -> HTTPCookie?,
        getUpgradePlanSession: @escaping (String) async -> String,
        getExtensionSessionSelector: @escaping (AppContext) async throws -> String
    ) {
        self.selector = selector
        self.sessionCookie = sessionCookie
        self.getUpgradePlanSession = getUpgradePlanSession
        self.getExtensionSessionSelector = getExtensionSessionSelector
    }

    public static let testValue: SessionService = {
        return SessionService(
            selector: unimplemented(),
            sessionCookie: unimplemented(placeholder: nil),
            getUpgradePlanSession: unimplemented(placeholder: ""),
            getExtensionSessionSelector: unimplemented(placeholder: "")
        )
    }()
}

extension DependencyValues {
    public var sessionService: SessionService {
        get { self[SessionService.self] }
        set { self[SessionService.self] = newValue }
    }
}
