//
//  Created on 2022-01-11.
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

public protocol BugReportDelegate {
    var model: BugReportModel { get }
    var prefilledEmail: String { get }
    
    typealias SendReportResult = Result<Void, Error>
    func send(form: BugReportResult, result: @escaping (SendReportResult) -> Void)
    
    func finished()
    func troubleshootingRequired()
}

// MARK: - Mocks

struct MockBugReportDelegate: BugReportDelegate {
    var model: BugReportModel
    var prefilledEmail: String = ""
    
    var sendCallback: ((BugReportResult, @escaping (SendReportResult) -> Void) -> Void)?
    
    func send(form: BugReportResult, result: @escaping (SendReportResult) -> Void) {
        sendCallback?(form, result)
    }
    
    var finishedCallback: (() -> Void)?
    
    func finished() {
        finishedCallback?()
    }
    
    var troubleshootingCallback: (() -> Void)?
    
    func troubleshootingRequired() {
        troubleshootingCallback?()
    }
}
