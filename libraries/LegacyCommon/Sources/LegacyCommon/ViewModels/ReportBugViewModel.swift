//
//  ReportBugViewModel.swift
//  vpncore - Created on 03/07/2019.
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

import Foundation
import ProtonCoreAPIClient
import VPNShared

public protocol ReportBugViewModelFactory {
    func makeReportBugViewModel() -> ReportBugViewModel
}

open class ReportBugViewModel {

    private var bug: ReportBug
    private var sendingBug: Bool = false
    private let propertiesManager: PropertiesManagerProtocol
    private let reportsApiService: ReportsApiService
    private let alertService: CoreAlertService
    private let logContentProvider: LogContentProvider
    private let logSources: [LogSource]
    
    private var planTitle: String?

    public typealias Factory = PropertiesManagerFactory &
        ReportsApiServiceFactory &
        CoreAlertServiceFactory &
        VpnKeychainFactory &
        LogContentProviderFactory &
        AuthKeychainHandleFactory

    public convenience init(_ factory: Factory, config: Container.Config) {
        self.init(os: config.os,
                  osVersion: config.osVersion,
                  propertiesManager: factory.makePropertiesManager(),
                  reportsApiService: factory.makeReportsApiService(),
                  alertService: factory.makeCoreAlertService(),
                  vpnKeychain: factory.makeVpnKeychain(),
                  logContentProvider: factory.makeLogContentProvider(),
                  authKeychain: factory.makeAuthKeychainHandle())
    }
    
    public init(os: String, osVersion: String, propertiesManager: PropertiesManagerProtocol, reportsApiService: ReportsApiService, alertService: CoreAlertService, vpnKeychain: VpnKeychainProtocol, logContentProvider: LogContentProvider, logSources: [LogSource] = LogSource.allCases, authKeychain: AuthKeychainHandle) {
        self.propertiesManager = propertiesManager
        self.reportsApiService = reportsApiService
        self.alertService = alertService
        self.logContentProvider = logContentProvider
        self.logSources = logSources
        
        let username = authKeychain.username.value ?? ""

        do {
            planTitle = try vpnKeychain.fetchCached().planTitle
        } catch let error {
            log.error("\(error)", category: .ui)
        }
        
        let clientVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        bug = ReportBug(os: os, osVersion: osVersion, client: "App", clientVersion: clientVersion, clientType: 2, title: "Report from \(os) app", description: "", username: username, email: propertiesManager.reportBugEmail ?? "", country: "", ISP: "", plan: planTitle ?? "")
    }
    
    public func set(description: String) {
        bug.description = description
    }
    
    public func set(email: String) {
        bug.email = email
    }
    
    public func getEmail() -> String? {
        return bug.email
    }
    
    public func set(country: String) {
        bug.country = country
    }
    
    public func getCountry() -> String? {
        return bug.country
    }
    
    public func set(isp: String) {
        bug.ISP = isp
    }
    
    public func getISP() -> String? {
        return bug.ISP
    }
    
    public func getUsername() -> String? {
        return bug.username
    }
    
    public func getClientVersion() -> String? {
        return bug.clientVersion
    }
    
    public func set(planTitle: String) {
        self.planTitle = planTitle
        bug.plan = planTitle
    }
    
    public func getPlanTitle() -> String? {
        return planTitle
    }
    
    public var isSendingPossible: Bool {
        return bug.canBeSent
    }

    public var logsEnabled: Bool = true

    public func send(completion: @escaping (Result<(), Error>) -> Void) {
        // Debounce multiple attempts to send a bug report (i.e., by mashing a button)
        guard !sendingBug else {
            return
        }

        guard logsEnabled else {
            self.bug.files = []
            send(report: bug, completion: completion)
            return
        }

        let tempLogFilesStorage = LogFilesTemporaryStorage(logContentProvider: logContentProvider, logSources: logSources)
        tempLogFilesStorage.prepareLogs { files in
            self.bug.files = files
            self.send(report: self.bug) { result in
                tempLogFilesStorage.deleteTempLogs()
                completion(result)
            }
        }
    }

    private func send(report: ReportBug, completion: @escaping (Result<(), Error>) -> Void) {
        sendingBug = true
        reportsApiService.report(bug: report) { [weak self] result in
            switch result {
            case .success:
                DispatchQueue.main.async { [weak self] in
                    self?.propertiesManager.reportBugEmail = self?.bug.email
                    self?.alertService.push(alert: BugReportSentAlert(confirmHandler: {
                        completion(.success)
                    }))
                    self?.sendingBug = false
                }
            case let .failure(apiError):
                DispatchQueue.main.async {
                    completion(.failure(apiError))
                    self?.sendingBug = false
                }
            }
        }
    }
    
}
