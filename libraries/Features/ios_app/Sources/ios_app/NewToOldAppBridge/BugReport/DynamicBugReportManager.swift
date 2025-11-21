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
import Foundation
import LegacyCommon
import PMLogger
import ProtonCoreAPIClient
import UIKit
import VPNAppCore
import VPNShared

public protocol DynamicBugReportManagerFactory {
    func makeDynamicBugReportManager() -> DynamicBugReportManager
}

public class DynamicBugReportManager {
    public var model: BugReportModel
    public var isUserCredentialless: Bool {
        @Dependency(\.credentiallessHelper) var credentiallessHelper
        return credentiallessHelper.isCredentialLess()
    }

    public var prefilledEmail: String {
        get {
            propertiesManager.reportBugEmail ?? ""
        }
        set {
            propertiesManager.reportBugEmail = newValue
        }
    }

    public var prefilledUsername: String {
        @Dependency(\.authKeychain) var authKeychain
        return authKeychain.username ?? ""
    }

    public var closeBugReportHandler: (() -> Void)? // To not have a dependency on windowService
    public var createAccountCallback: (() -> Void)? // To not have a depdendency on navigationService
    public var signInCallback: (() -> Void)? // To not have a depdendency on navigationService

    @Dependency(\.reportsApiClient) private var reportsApiClient
    @Dependency(\.dynamicBugReportStorage) private var storage
    private var alertService: CoreAlertService
    @Dependency(\.propertiesManager) private var propertiesManager
    private var timer: Timer?
    private let updateChecker: UpdateChecker
    @Dependency(\.vpnKeychain) private var vpnKeychain
    @Dependency(\.logContentProvider) private var logContentProvider
    private let logSources: [LogSource]

    public typealias Factory = CoreAlertServiceFactory & UpdateCheckerFactory

    public convenience init(_ factory: Factory) {
        self.init(
            alertService: factory.makeCoreAlertService(),
            updateChecker: factory.makeUpdateChecker()
        )
    }

    public init(
        alertService: CoreAlertService,
        updateChecker: UpdateChecker,
        logSources: [LogSource] = LogSource.allCases
    ) {
        self.alertService = alertService
        self.updateChecker = updateChecker
        self.logSources = logSources

        @Dependency(\.dynamicBugReportStorage) var storage
        self.model = storage.fetch() ?? Self.getDefaultConfig()
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
            model = config
            storage.store(config)
            log.debug("Dynamic bug report config downloaded and saved", category: .app)
        } catch {
            log.debug("Dynamic bug report config download error", category: .app, event: .error, metadata: ["error": "\(error)"])
            // Ignoring this error as we have default config
        }
    }

    private static func getDefaultConfig() -> BugReportModel {
        let bundle = Bundle.module
        guard let configFile = bundle.url(forResource: "BugReportConfig", withExtension: "json") else {
            log.error("BugReportConfig.json file not found. Returning empty config.", category: .app)
            return BugReportModel()
        }
        do {
            let data = try Data(contentsOf: configFile)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .custom(decapitalizeFirstLetter)
            return try decoder.decode(BugReportModel.self, from: data)

        } catch {
            return BugReportModel()
        }
    }

    private func fillReportBug(withData data: BugReportResult) -> ReportBug {
        let os = "iOS"
        let osVersion = UIDevice.current.systemVersion

        @Dependency(\.appInfo) var appInfo

        let report = ReportBug(
            os: os,
            osVersion: osVersion,
            client: "App",
            clientVersion: "\(appInfo.bundleShortVersion) (\(appInfo.bundleVersion))",
            clientType: 2,
            title: "Report from \(os) app",
            description: data.text,
            username: data.username,
            email: data.email,
            country: propertiesManager.userLocation?.country ?? "",
            ISP: propertiesManager.userLocation?.isp ?? "",
            plan: (try? vpnKeychain.fetchCached().planTitle) ?? ""
        )

        return report
    }

    // BugReportDelegate
    public var updateAvailabilityChanged: ((Bool) -> Void)?
}

extension DynamicBugReportManager: BugReportDelegate {
    public func send(form: BugReportResult) async throws {
        var report = fillReportBug(withData: form)

        guard form.logs else {
            return try await send(report: report)
        }

        propertiesManager.logCurrentState()
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

    public func finished() {
        closeBugReportHandler?()
    }

    public func troubleshootingRequired() {
        alertService.push(alert: ConnectionTroubleshootingAlert())
    }

    public func updateApp() {
        updateChecker.startUpdate()
    }

    public func checkUpdateAvailability() {
        Task.detached {
            let available = await self.updateChecker.isUpdateAvailable()
            self.updateAvailabilityChanged?(available)
        }
    }

    public func createAccount() {
        createAccountCallback?()
    }

    public func signIn() {
        signInCallback?()
    }
}

func decapitalizeFirstLetter(_ path: [CodingKey]) -> CodingKey {
    let original: String = path.last!.stringValue
    let uncapitalized = original.prefix(1).lowercased() + original.dropFirst()
    return JSONKey(stringValue: uncapitalized) ?? path.last!
}

private struct JSONKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
