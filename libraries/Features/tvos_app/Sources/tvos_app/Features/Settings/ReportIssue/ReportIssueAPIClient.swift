//
//  Created on 23/02/2026 by Max Kupetskyi.
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

import CommonNetworking
import Dependencies
import DependenciesMacros
import Foundation
import ProtonCoreAPIClient

@DependencyClient
struct ReportIssueAPIClient: Sendable {
    var send: @Sendable (_ report: ReportBug) async throws -> ReportsBugResponse
}

extension ReportIssueAPIClient: DependencyKey {
    static let liveValue = ReportIssueAPIClient(
        send: { report in
            @Dependency(\.networking) var networking

            let files = report.files.reachable()
                .enumerated()
                .reduce(into: [String: URL]()) { result, file in
                    result["File\(file.offset)"] = file.element
                }

            let request = TVOSReportIssueRequest(report)
            return try await networking.perform(request: request, files: files)
        }
    )
}

extension DependencyValues {
    var reportIssueAPIClient: ReportIssueAPIClient {
        get { self[ReportIssueAPIClient.self] }
        set { self[ReportIssueAPIClient.self] = newValue }
    }
}
