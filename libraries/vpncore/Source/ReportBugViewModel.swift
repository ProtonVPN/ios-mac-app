//
//  ReportBugViewModel.swift
//  vpncore - Created on 03/07/2019.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
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
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

public protocol ReportBugViewModelFactory {
    func makeReportBugViewModel() -> ReportBugViewModel
}

open class ReportBugViewModel {
    
    public var attachmentsListRefreshed: (() -> Void)?
    
    private var bug: ReportBug
    private let propertiesManager: PropertiesManagerProtocol
    private let reportsApiService: ReportsApiService
    private let alertService: CoreAlertService
    
    private var plan: AccountPlan?
    
    public init(os: String, osVersion: String, propertiesManager: PropertiesManagerProtocol, reportsApiService: ReportsApiService, alertService: CoreAlertService, vpnKeychain: VpnKeychainProtocol) {
        self.propertiesManager = propertiesManager
        self.reportsApiService = reportsApiService
        self.alertService = alertService
        
        var username = ""
        if let authCredentials = AuthKeychain.fetch() {
            username = authCredentials.username
        }
        
        do {
            plan = try vpnKeychain.fetch().accountPlan
        } catch let error {
            PMLog.ET(error.localizedDescription)
        }
        
        let clientVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        bug = ReportBug(os: os, osVersion: osVersion, client: "App", clientVersion: clientVersion, clientType: 2, title: "Report from \(os) app", description: "", username: username, email: propertiesManager.reportBugEmail ?? "", country: "", ISP: "", plan: plan?.description ?? "")
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
    
    public func set(accountPlan: AccountPlan) {
        plan = accountPlan
        bug.plan = plan?.description ?? ""
    }
    
    public func getAccountPlan() -> AccountPlan? {
        return plan
    }
    
    public func add(files: [URL]) {
        for file in files where !bug.files.contains(file) {
            bug.files.append(file)
        }
        attachmentsListRefreshed?()
    }
    
    public func remove(file: URL) {
        bug.files.removeAll(where: { $0 == file })
        attachmentsListRefreshed?()
    }
    
    public var filesCount: Int {
        return bug.files.count
    }
    
    public func fileAttachment(atRow row: Int) -> AttachmentRowViewModel {
        return AttachmentRowViewModel(url: bug.files[row], parent: self)
    }
    
    public var isSendingPossible: Bool {
        return bug.canBeSent
    }
    
    public func send(success: @escaping () -> Void, error: @escaping (Error) -> Void) {
        reportsApiService.report(bug: bug, success: {
            DispatchQueue.main.async {
                self.propertiesManager.reportBugEmail = self.bug.email
                self.alertService.push(alert: BugReportSentAlert(confirmHandler: {
                    success()
                }))
            }
        }, failure: { apiError in
            DispatchQueue.main.async {
                error(apiError)
            }
        })
    }
    
}
