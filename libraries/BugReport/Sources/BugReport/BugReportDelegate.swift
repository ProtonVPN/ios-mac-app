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

/// Delegate that is used by this BugReport library to communicate wit hthe app.
public protocol BugReportDelegate: AnyObject {

    /// Configuration for Dynamic Bug Report UI.
    var model: BugReportModel { get }

    /// If app knows users email, it should be returned here.
    var prefilledEmail: String { get }

    /// If app knows the username, it should be returned here.
    var prefilledUsername: String { get }

    /// This method should send filled-in form to API and call `result` callback when finished.
    func send(form: BugReportResult, result: @escaping (SendReportResult) -> Void)
    typealias SendReportResult = Result<Void, Error>

    /// This method called after used presses OK button on final `success` screen.
    func finished()

    /// This method is called when user presses `Troubleshooting` button in final `failure` screen. It should show apps troubleshooting screen.
    func troubleshootingRequired()

    /// Asynchronously check if updates available. If/when availability status changes, `updateAvailabilityChanged` will be called
    func checkUpdateAvailability()

    /// Callback that is called when update availability status changes
    var updateAvailabilityChanged: ((Bool) -> Void)? { get set }

    /// Callback that starts updating the app.
    func updateApp()
}
