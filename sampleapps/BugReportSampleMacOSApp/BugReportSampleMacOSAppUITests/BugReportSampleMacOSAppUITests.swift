//
//  Created on 2022-01-28.
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

import XCTest

class BugReportSampleMacOSAppUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
        
        let app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    private let bugReportRobot = BugReportRobot()
        
    func testSendBugReportSomethingElse() {
            
        let email = "success@email.com"
        let text = "Desccription"
            
        bugReportRobot
            .openBugReport()
            .reportSomethingElseIssue()
            .verify.bugReportFormIsShown()
            .enterEmailAddress(email)
            .enterDescription(text)
            .sendBugReport()
            .verify.successMessageIsShown()
    }
        
    func testSendBugReportBrowsingSpeed() {
            
        let email = "success@email.com"
        let text = "Description"
            
        bugReportRobot
            .openBugReport()
            .reportBrowsingSpeedIssue()
            .verify.browsingSpeedScreenIsShown()
            .contactUs()
            .verify.bugReportFormIsShown()
            .enterEmailAddress(email)
            .fillDetails(text)
            .toggleSendLogs()
            .sendBugReport()
            .verify.successMessageIsShown()
    }
        
    func testSendBugReportWithError() {
            
        let email = "success@email"
        let description = "Description"
        
        bugReportRobot
            .openBugReport()
            .reportSomethingElseIssue()
            .verify.bugReportFormIsShown()
            .enterEmailAddress(email)
            .enterDescription(description)
            .sendBugReport()
            .openTroubleshootScreen()
            .verify.troubleshootButtonIsClicked()
            .verify.errorMessageIsShown()
    }
        
    func testBugReportBackButton() {
            
        bugReportRobot
            .openBugReport()
            .reportUsingTheAppIssue()
            .verify.usingTheAppScreenIsShown()
            .contactUs()
            .verify.bugReportFormIsShown()
            .backToPreviousScreen()
            .verify.usingTheAppScreenIsShown()
            .backToPreviousScreen()
            .verify.reportAnIssueScreenIsShown()
    }
}
