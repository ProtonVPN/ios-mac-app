//
//  Created on 2022-01-17.
//
//  Copyright (c) 2022 Proton AG
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

import CommonNetworking
import Dependencies
import Foundation
import VPNShared

public struct DynamicBugReportStorage {
    public var fetch: () -> BugReportModel?
    public var store: (BugReportModel) -> Void
    public var clear: () -> Void
}

extension DynamicBugReportStorage: TestDependencyKey {
    public static var testValue: DynamicBugReportStorage = {
        fatalError("\(Self.self) must have a implementation")
    }()
}

public extension DependencyValues {
    var dynamicBugReportStorage: DynamicBugReportStorage {
        get { self[DynamicBugReportStorage.self] }
        set { self[DynamicBugReportStorage.self] = newValue }
    }
}

extension DynamicBugReportStorage: DependencyKey {
    public static var liveValue: DynamicBugReportStorage = {
        @Dependency(\.storage) var storage
        let storageKey = "DynamicBugReport"

        return DynamicBugReportStorage(
            fetch: {
                try? storage.get(BugReportModel.self, forKey: storageKey)

            },
            store: { bugReport in
                try? storage.set(bugReport, forKey: storageKey)

            },
            clear: {
                storage.removeObject(forKey: storageKey)
            }
        )
    }()
}
