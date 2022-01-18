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
    
    public var closeBugReportHandler: (() -> Void)? // To not have a dependency on windowService
    public var username: String = ""
    public var planname: String = ""
    
    private var api: ReportsApiService
    private var storage: DynamicBugReportStorage
    private var alertService: CoreAlertService
    private var propertiesManager: PropertiesManagerProtocol
    private var logFilesProvider: LogFilesProvider
    private var timer: Timer?
    
    public init(api: ReportsApiService, storage: DynamicBugReportStorage, alertService: CoreAlertService, propertiesManager: PropertiesManagerProtocol, logFilesProvider: LogFilesProvider) {
        self.api = api
        self.storage = storage
        self.alertService = alertService
        self.propertiesManager = propertiesManager
        self.logFilesProvider = logFilesProvider
        
        model = storage.fetch() ?? getDefaultConfig()
        setupRefresh()
    }
    
    // Refresh config on every app start and then once a day
    private func setupRefresh() {
        loadConfig()
        timer = Timer(fire: .tomorrow, interval: .day, repeats: true, block: { _ in self.loadConfig() })
    }
    
    private func loadConfig() {
        api.dynamicBugReportConfig(success: { result in
            self.model = result
            self.storage.store(result)
            log.debug("Dynamic bug report config downloaded and saved", category: .app)
            
        }, failure: { error in
            log.debug("Dynamic bug report config download error", category: .app, event: .error, metadata: ["error": "\(error)"])
            // Ignoring this error as we have default config
        })
    }
    
    private func getDefaultConfig() -> BugReportModel {
        let bundle = Bundle.main
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
        let clientVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        #elseif os(macOS)
        
        #endif
        
        var report = ReportBug(os: os,
                               osVersion: osVersion,
                               client: "App",
                               clientVersion: clientVersion,
                               clientType: 2,
                               title: "Report from \(os) app",
                               description: data.text,
                               username: username,
                               email: data.email,
                               country: "",
                               ISP: "",
                               plan: planname)
        
        if data.logs {
            report.files = logFilesProvider.logFiles.compactMap { $0.1 }.reachable()
        }
        
        return report
    }
    
}

extension DynamicBugReportManager: BugReportDelegate {
        
    public func send(form: BugReportResult, result: @escaping (SendReportResult) -> Void) {
        let report = fillReportBug(withData: form)
        api.report(bug: report, success: {
            self.prefilledEmail = report.email
            result(.success(()))
        }, failure: { error in
            result(.failure(error))
        })
    }
    
    public func finished() {
        closeBugReportHandler?()
    }
    
    public func troubleshootingRequired() {
        alertService.push(alert: ConnectionTroubleshootingAlert())
    }
    
}
