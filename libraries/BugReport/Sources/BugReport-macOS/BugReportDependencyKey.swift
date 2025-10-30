//
//  Created on 2025-03-07.
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

import AppKit

import BugReportShared
import Dependencies

public struct BugReportDependencyKey: DependencyKey {
    public static let liveValue: BugReportCreator = MacOSBugReportCreator()
    public static let testValue: BugReportCreator = MockBugReportCreator()
}

public extension DependencyValues {
    var bugReport: BugReportCreator {
        get { self[BugReportDependencyKey.self] }
        set { self[BugReportDependencyKey.self] = newValue }
    }
}

struct MockBugReportCreator: BugReportCreator {
    func createBugReportViewController(delegate _: any BugReportShared.BugReportDelegate, colors _: BugReportShared.Colors) -> NSViewController {
        .init()
    }
}
