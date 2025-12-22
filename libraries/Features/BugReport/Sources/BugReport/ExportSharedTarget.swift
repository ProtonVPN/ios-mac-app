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

import Dependencies

import BugReportShared

public typealias BugReportDelegate = BugReportShared.BugReportDelegate
public typealias BugReportResult = BugReportShared.BugReportResult
public typealias Colors = BugReportShared.Colors
// TODO: Soon to be removed VPNAPPL-3256
public typealias TroubleshootViewModel = BugReportShared.TroubleshootViewModel
public typealias TroubleshootViewModelFactory = BugReportShared.TroubleshootViewModelFactory

#if canImport(BugReport_macOS)

    import BugReport_macOS

    public typealias BugReportDependencyKey = BugReport_macOS.BugReportDependencyKey
    public typealias TroubleshootingPopup = BugReport_macOS.TroubleshootingPopup

#elseif canImport(BugReport_iOS)

    import BugReport_iOS

    public typealias BugReportDependencyKey = BugReport_iOS.BugReportDependencyKey
    public typealias TroubleshootViewController = BugReport_iOS.TroubleshootViewController

#endif

public extension DependencyValues {
    var bugReport: BugReportCreator {
        get { self[BugReportDependencyKey.self] }
        set { self[BugReportDependencyKey.self] = newValue }
    }
}
