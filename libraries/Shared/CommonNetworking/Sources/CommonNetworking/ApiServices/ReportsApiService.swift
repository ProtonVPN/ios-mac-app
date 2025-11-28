//
//  ReportsApiService.swift
//  vpncore - Created on 01/07/2019.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import Dependencies
import DependenciesMacros
import Foundation
import ProtonCoreAPIClient
import VPNShared

@DependencyClient
public struct ReportsApiClient: Sendable {
    public internal(set) var report: @Sendable (ReportBug) async throws -> ReportsBugResponse
    public internal(set) var dynamicBugReportConfig: @Sendable () async throws -> BugReportModel
}

public enum ReportsApiClientKey: DependencyKey {
    public static var liveValue: ReportsApiClient = {
        @Dependency(\.networking) var networking
        return ReportsApiClient(
            report: { bug in
                let files = bug.files.reachable()
                    .enumerated()
                    .reduce(into: [String: URL]()) { result, file in
                        result["File\(file.offset)"] = file.element
                    }

                let request = ReportsBugs1(bug)
                return try await networking.perform(request: request, files: files)
            },
            dynamicBugReportConfig: {
                try await networking.perform(request: DynamicBugReportConfigRequest())
            }
        )
    }()
}

public extension DependencyValues {
    var reportsApiClient: ReportsApiClient {
        get { self[ReportsApiClientKey.self] }
        set { self[ReportsApiClientKey.self] = newValue }
    }
}
