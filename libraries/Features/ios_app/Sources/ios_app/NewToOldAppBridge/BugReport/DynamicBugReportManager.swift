//
//  Created on 2022-01-14.
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

import BugReport
import CommonNetworking
import Dependencies
import Domain
import Foundation
import PMLogger
import ProtonCoreAPIClient
import Sharing
import UIKit
import VPNAppCore
import VPNShared

class DynamicBugReportManager {
    @Shared(.dynamicBugReport) var model
    var isUserCredentialless: Bool {
        @Dependency(\.credentiallessHelper) var credentiallessHelper
        return credentiallessHelper.isCredentialLess()
    }

    var prefilledEmail: String {
        get {
            @SharedReader(.reportBugEmail) var reportBugEmail
            return reportBugEmail ?? ""
        }
        set {
            @Shared(.reportBugEmail) var reportBugEmail
            $reportBugEmail.withLock { $0 = newValue }
        }
    }

    var prefilledUsername: String {
        @Dependency(\.authKeychain) var authKeychain
        return authKeychain.username ?? ""
    }

    var closeBugReportHandler: (() -> Void)? // To not have a dependency on windowService
    var createAccountCallback: (() -> Void)? // To not have a depdendency on navigationService
    var signInCallback: (() -> Void)? // To not have a depdendency on navigationService

    @Dependency(\.reportsApiClient) private var reportsApiClient
    private var timer: Timer?
    @Dependency(\.updateManager) private var updateManager
    @Dependency(\.credentialsProvider) private var credentialsProvider
    @Dependency(\.logContentProvider) private var logContentProvider
    private let logSources: [LogSource]

    init(logSources: [LogSource] = LogSource.allCases) {
        self.logSources = logSources
        setupRefresh()
    }

    // Refresh config on every app start and then once a day
    private func setupRefresh() {
        Task {
            await loadConfig()
        }
        timer = Timer(fire: Date().addingTimeInterval(.days(1)), interval: .days(1), repeats: true, block: { _ in
            Task {
                await self.loadConfig()
            }
        })
    }

    private func loadConfig() async {
        do {
            let config = try await reportsApiClient.dynamicBugReportConfig()
            $model.withLock { $0 = config }
            log.debug("Dynamic bug report config downloaded and saved", category: .app)
        } catch {
            log.debug("Dynamic bug report config download error", category: .app, event: .error, metadata: ["error": "\(error)"])
            // Ignoring this error as we have default config
        }
    }

    private func fillReportBug(withData data: BugReportResult) -> ReportBug {
        @Dependency(\.appInfo) var appInfo
        @SharedReader(.userLocation) var userLocation
        let os = appInfo.platformName

        return ReportBug(
            os: os,
            osVersion: appInfo.osVersion().osVersionString,
            client: "App",
            clientVersion: "\(appInfo.bundleShortVersion) (\(appInfo.bundleVersion))",
            clientType: 2,
            title: "Report from \(os) app",
            description: data.text,
            username: data.username,
            email: data.email,
            country: userLocation?.location.country ?? "",
            ISP: userLocation?.location.isp ?? "",
            plan: credentialsProvider.planTitle ?? ""
        )
    }

    // BugReportDelegate
    var updateAvailabilityChanged: ((Bool) -> Void)?
}

extension DynamicBugReportManager: BugReportDelegate {
    func send(form: BugReportResult) async throws {
        var report = fillReportBug(withData: form)

        guard form.logs else {
            return try await send(report: report)
        }

        let tempLogFilesStorage = LogFilesTemporaryStorage(logSources: logSources)

        let logFiles = await withCheckedContinuation { continuation in
            tempLogFilesStorage.prepareLogs { logFiles in
                continuation.resume(returning: logFiles)
            }
        }

        report.files = logFiles
        try await send(report: report)
        tempLogFilesStorage.deleteTempLogs()
    }

    private func send(report: ReportBug) async throws {
        try await reportsApiClient.report(report)
        prefilledEmail = report.email
    }

    func finished() {
        closeBugReportHandler?()
    }

    func updateApp() {
        updateManager.startUpdate()
    }

    func checkUpdateAvailability() {
        Task.detached {
            let available = await self.updateManager.isUpdateAvailable()
            self.updateAvailabilityChanged?(available)
        }
    }

    func createAccount() {
        createAccountCallback?()
    }

    func signIn() {
        signInCallback?()
    }
}
