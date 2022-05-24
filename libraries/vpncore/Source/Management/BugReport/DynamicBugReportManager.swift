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

import Foundation
import ProtonCore_APIClient
import BugReport

#if os(iOS)
import UIKit
#elseif os(macOS)

#endif

public protocol DynamicBugReportManagerFactory {
    func makeDynamicBugReportManager() -> DynamicBugReportManager
}

public class DynamicBugReportManager {
    
    public var model: BugReportModel = .mock
    public var prefilledEmail: String {
        get {
            return self.propertiesManager.reportBugEmail ?? ""
        }
        set {
            self.propertiesManager.reportBugEmail = newValue
        }
    }
    public var prefilledUsername: String {
        return AuthKeychain.fetch()?.username ?? ""
    }
    
    public var closeBugReportHandler: (() -> Void)? // To not have a dependency on windowService
    
    private var api: ReportsApiService
    private var storage: DynamicBugReportStorage
    private var alertService: CoreAlertService
    private var propertiesManager: PropertiesManagerProtocol
    private var timer: Timer?
    private let updateChecker: UpdateChecker
    private let vpnKeychain: VpnKeychainProtocol
    private let logContentProvider: LogContentProvider
    private let logSources: [LogSource]

    public init(api: ReportsApiService, storage: DynamicBugReportStorage, alertService: CoreAlertService, propertiesManager: PropertiesManagerProtocol, updateChecker: UpdateChecker, vpnKeychain: VpnKeychainProtocol, logContentProvider: LogContentProvider, logSources: [LogSource] = LogSource.allCases) {
        self.api = api
        self.storage = storage
        self.alertService = alertService
        self.propertiesManager = propertiesManager
        self.updateChecker = updateChecker
        self.vpnKeychain = vpnKeychain
        self.logContentProvider = logContentProvider
        self.logSources = logSources
        
        model = storage.fetch() ?? getDefaultConfig()
        setupRefresh()
    }
    
    // Refresh config on every app start and then once a day
    private func setupRefresh() {
        loadConfig()
        timer = Timer(fire: Date().addingTimeInterval(.day), interval: .day, repeats: true, block: { _ in self.loadConfig() })
    }
    
    private func loadConfig() {
        api.dynamicBugReportConfig { result in
            switch result {
            case .success(let config):
                self.model = config
                self.storage.store(config)
                log.debug("Dynamic bug report config downloaded and saved", category: .app)
                
            case .failure(let error):
                log.debug("Dynamic bug report config download error", category: .app, event: .error, metadata: ["error": "\(error)"])
                // Ignoring this error as we have default config
            }
        }
    }
    
    private func getDefaultConfig() -> BugReportModel {
        let bundle = Bundle.vpnCore
        guard let configFile = bundle.url(forResource: "BugReportConfig", withExtension: "json") else {
            log.error("BugReportConfig.json file not found. Returning empty config.")
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
        #if os(iOS)
        let os = "iOS"
        let osVersion = UIDevice.current.systemVersion
        #elseif os(macOS)
        let os = "MacOS"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        #endif

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

        var report = ReportBug(os: os,
                               osVersion: osVersion,
                               client: "App",
                               clientVersion: "\(appVersion) (\(appBuild))",
                               clientType: 2,
                               title: "Report from \(os) app",
                               description: data.text,
                               username: data.username,
                               email: data.email,
                               country: propertiesManager.userLocation?.country ?? "",
                               ISP: propertiesManager.userLocation?.isp ?? "",
                               plan: (try? vpnKeychain.fetchCached().accountPlan.description) ?? "")
        
        return report
    }
    
    // BugReportDelegate
    public var updateAvailabilityChanged: ((Bool) -> Void)?
    
}

extension DynamicBugReportManager: BugReportDelegate {
    public func send(form: BugReportResult, result: @escaping (SendReportResult) -> Void) {
        var report = fillReportBug(withData: form)

        if form.logs {
            propertiesManager.logCurrentState()
            prepareLogs(responseHandler: { logFiles in
                report.files = logFiles
                self.send(report: report) { reportResult in
                    self.deleteTempLog(files: logFiles)
                    result(reportResult)
                }
            })
            return
        }

        send(report: report, result: result)
    }

    private func send(report: ReportBug, result: @escaping (SendReportResult) -> Void) {
        api.report(bug: report) { requestResult in
            self.deleteTempLog(files: report.files)

            switch requestResult {
            case .success:
                self.prefilledEmail = report.email
                result(.success(()))

            case .failure(let error):
                result(.failure(error))
            }
        }
    }
    
    public func finished() {
        closeBugReportHandler?()
    }
    
    public func troubleshootingRequired() {
        alertService.push(alert: ConnectionTroubleshootingAlert())
    }

    public func updateApp() {
        return updateChecker.startUpdate()
    }
    
    public func checkUpdateAvailability() {
        self.updateChecker.isUpdateAvailable { available in
            self.updateAvailabilityChanged?(available)
        }
    }

    // MARK: - Log files

    /// Writes logs to temporary files that can be uploaded to API
    private func prepareLogs(responseHandler: @escaping ([URL]) -> Void) {
        let fileManager = FileManager.default
        var result: [URL] = []
        let dispatchGroup = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInitiated) // For writing to array without race conditions

        logSources.forEach { source in
            dispatchGroup.enter()

            let contentProvider = self.logContentProvider.getLogData(for: source)
            contentProvider.loadContent { content in
                guard !content.isEmpty else {
                    dispatchGroup.leave()
                    return
                }

                let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("\(source.title).log")
                do {
                    if fileManager.fileExists(atPath: tempFile.path) {
                        try fileManager.removeItem(at: tempFile)
                    }

                    try content.write(to: tempFile, atomically: true, encoding: .utf8)

                    queue.async {
                        result.append(tempFile)
                        dispatchGroup.leave()
                    }

                } catch {
                    log.error("Can't save temporary log file", category: .app, event: .error, metadata: ["error": "\(error)", "source": "\(source.title)", "file": "\(tempFile)"])
                    dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: DispatchQueue.main) {
            responseHandler(result)
        }
    }

    /// Deletes temp log files after upload is done
    private func deleteTempLog(files: [URL]) {
        files.forEach { file in
            try? FileManager.default.removeItem(at: file)
        }
    }
}
