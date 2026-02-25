//
//  Created on 02/03/2026 by Max Kupetskyi.
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
import ProtonCoreAPIClient
import ProtonCoreNetworking
import VPNShared

final class TVOSReportIssueRequest: Request {
    private let report: ReportBug

    @Dependency(\.authKeychain) private var authKeychain

    init(_ report: ReportBug) {
        self.report = report
    }

    var path: String {
        "/core/v4/reports/bug"
    }

    var method: HTTPMethod {
        .post
    }

    var parameters: [String: Any]? {
        [
            "OS": report.os,
            "OSVersion": report.osVersion,
            "Client": report.client,
            "ClientVersion": report.clientVersion,
            "ClientType": String(report.clientType),
            "Title": report.title,
            "Description": report.description,
            "Username": report.username,
            "Email": report.email,
            "Country": report.country,
            "ISP": report.ISP,
            "Plan": report.plan,
        ]
    }

    var isAuth: Bool {
        authKeychain.username != nil
    }
}

struct ReportIssueForm: Sendable {
    let username: String
    let email: String
    let whatAreYouTryingToDo: String
    let whatWentWrong: String
    let shouldSendErrorLogs: Bool

    func asBugReport() async throws -> (report: ReportBug, temporaryLogFileURL: URL?) {
        var report = baseReport
        guard shouldSendErrorLogs else {
            return (report, nil)
        }

        @Dependency(\.logContentProvider) var logContentProvider
        let logs = await logContentProvider.getLogData(for: .app).loadContent()
        let fileURL = URL.temporaryDirectory.appendingPathComponent("ProtonVPN-tvOS-report.log")
        try logs.write(to: fileURL, atomically: true, encoding: .utf8)
        report.files = [fileURL]

        return (report, fileURL)
    }

    private var baseReport: ReportBug {
        @Dependency(\.appInfo) var appInfo

        return ReportBug(
            os: appInfo.platformName,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            client: "App",
            clientVersion: "\(appInfo.bundleShortVersion) (\(appInfo.bundleVersion))",
            clientType: 2,
            title: "Report from \(appInfo.platformName) app",
            description: """
            What are you trying to do:
            \(whatAreYouTryingToDo)
            ---
            What went wrong:
            \(whatWentWrong)
            ---
            """,
            username: username,
            email: email,
            country: "",
            ISP: "",
            plan: ""
        )
    }
}
