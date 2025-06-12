//
//  Created on 2022-02-02.
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

let app = XCUIApplication()

private let bugReportHeading = "Report an issue"
private let backButton = "Back"
private let showBugReportButton = "Show bug report"
// Step 1
private let stepOneTitle = "What's the issue?"
private let browsingSpeedIssue = "Browsing speed_"
private let usingTheAppIssue = "Using the app_"
private let somethingElseIssue = "Something else_"
// Step 2
private let stepTwoTitle = "Quick fixes"
private let stepTwoSubtitle = "These tips could help to solve your issue faster."
private let fixOne = "Log out and log back in."
private let fixTwo = "Restart the app."
private let fixThree = "Try a different server. Servers in nearby countries often have faster connection speeds."
private let contactUsButton = "Contact us"
private let cancelButton = "Cancel"
// Step 3
private let emailTextField = "Single line input _email"
private let whatWentWrongTextField = "Multiline input What went wrong?"
private let networkTypeTextField = "Single line input Network type"
private let whatAreYouTringToDoTextField = "Multiline input What are you trying to do?"
private let whatIsTheSpeedTextField = "Single line input What is the speed you are getting?"
private let connectionSpeedTextField = "Single line input What is your connection speed without VPN?"
private let logsSwitch = "Toggle _logs"
private let logsWarning = "Error logs help us to get to the bottom of your issue. If you don’t include them, we might not be able to investigate fully."
private let sendReportButton = "Send report"
// Messages
private let successMessageTitle = "Thanks for your feedback"
private let errorMessageTitle = "Your report wasn’t sent"
private let gotItButton = "Got it"
private let tryAgainButton = "Try again"
private let troubleshootgButton = "Troubleshoot"
private let statusLabel = "Troubleshooting"

class BugReportRobot {
    func openBugReport() -> BugReportRobot {
        app.buttons[showBugReportButton].tap()
        return BugReportRobot()
    }

    func reportSomethingElseIssue() -> BugReportRobot {
        app.buttons[somethingElseIssue].tap()
        return BugReportRobot()
    }
    
    func contactUs() -> BugReportRobot {
        app.buttons[contactUsButton].tap()
        return BugReportRobot()
    }
    
    func cancelReport() -> BugReportRobot {
        app.buttons[cancelButton].tap()
        return BugReportRobot()
    }
    
    func reportUsingTheAppIssue() -> BugReportRobot {
        app.buttons[usingTheAppIssue].tap()
        return BugReportRobot()
    }
    
    func reportBrowsingSpeedIssue() -> BugReportRobot {
        app.buttons[browsingSpeedIssue].tap()
        return BugReportRobot()
    }
    
    func enterEmailAddress(_ email: String) -> BugReportRobot {
        app.textFields[emailTextField].tap()
        app.textFields[emailTextField].typeText(email)
        return BugReportRobot()
    }
    
    func enterDescription(_ text: String) -> BugReportRobot {
        app.textViews[whatWentWrongTextField].tap()
        app.textViews[whatWentWrongTextField].typeText(text)
        return BugReportRobot()
    }
    
    func fillDetails(_ text: String) -> BugReportRobot {
        app.textFields[networkTypeTextField].tap()
        app.textFields[networkTypeTextField].typeText(text)
        app.textViews[whatAreYouTringToDoTextField].tap()
        app.textViews[whatAreYouTringToDoTextField].typeText(text)
        app.textFields[whatIsTheSpeedTextField].tap()
        app.textFields[whatIsTheSpeedTextField].typeText(text)
        app.textFields[connectionSpeedTextField].tap()
        app.textFields[connectionSpeedTextField].typeText(text)
        XCUIApplication().keyboards.buttons["Return"].tap()
        return BugReportRobot()
    }
    
    func sendBugReport() -> BugReportRobot {
        app.buttons[sendReportButton].tap()
        return BugReportRobot()
    }
    
    // need to fix toggle a11y
    func toggleSendLogs() -> BugReportRobot {
        app.switches[logsSwitch].firstMatch.tap()
        XCTAssertTrue(app.staticTexts[logsWarning].exists)
        app.switches[logsSwitch].firstMatch.tap()
        return BugReportRobot()
    }
    
    func backToPreviousScreen() -> BugReportRobot {
        app.buttons[backButton].tap()
        return BugReportRobot()
    }
    
    func openTroubleshootScreen() -> BugReportRobot {
        XCTAssert(app.buttons[troubleshootgButton].waitForExistence(timeout: 3))
        app.buttons[troubleshootgButton].tap()
        return BugReportRobot()
    }
    
    public let verify = Verify()
    
    class Verify {
        @discardableResult
        func reportAnIssueScreenIsShown() -> BugReportRobot {
            XCTAssertTrue(app.staticTexts[bugReportHeading].exists)
            XCTAssertTrue(app.staticTexts[stepOneTitle].exists)
            XCTAssertTrue(app.buttons[usingTheAppIssue].isEnabled)
            XCTAssertTrue(app.buttons[somethingElseIssue].isEnabled)
            return BugReportRobot()
        }
        
        @discardableResult
        func usingTheAppScreenIsShown() -> BugReportRobot {
            XCTAssertTrue(app.staticTexts[stepTwoTitle].exists)
            XCTAssertTrue(app.staticTexts[stepTwoSubtitle].exists)
            XCTAssertTrue(app.staticTexts[fixOne].exists)
            XCTAssertTrue(app.staticTexts[fixTwo].exists)
            XCTAssertTrue(app.buttons[contactUsButton].isEnabled)
            XCTAssertTrue(app.buttons[cancelButton].isEnabled)
            return BugReportRobot()
        }
        
        func browsingSpeedScreenIsShown() -> BugReportRobot {
            XCTAssertTrue(app.staticTexts[stepTwoTitle].exists)
            XCTAssertTrue(app.staticTexts[stepTwoSubtitle].exists)
            XCTAssertTrue(app.staticTexts[fixThree].exists)
            XCTAssertTrue(app.buttons[contactUsButton].isEnabled)
            XCTAssertTrue(app.buttons[cancelButton].isEnabled)
            return BugReportRobot()
        }
        
        @discardableResult
        func bugReportFormIsShown() -> BugReportRobot {
            XCTAssert(app.textFields[emailTextField].waitForExistence(timeout: 6))
            XCTAssertFalse(app.buttons[sendReportButton].isEnabled)
            return BugReportRobot()
        }
        
        @discardableResult
        func sendErrorLogsWarningIsShown() -> BugReportRobot {
            XCTAssertTrue(app.staticTexts[logsWarning].exists)
            return BugReportRobot()
        }
        
        @discardableResult
        func successMessageIsShown() -> BugReportRobot {
            XCTAssert(app.staticTexts[successMessageTitle].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons[gotItButton].isEnabled)
            app.buttons[gotItButton].tap()
            return BugReportRobot()
        }
        
        @discardableResult
        func errorMessageIsShown() -> BugReportRobot {
            XCTAssert(app.staticTexts[errorMessageTitle].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons[tryAgainButton].isEnabled)
            app.buttons[tryAgainButton].tap()
            XCTAssert(app.textFields[emailTextField].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons[sendReportButton].isEnabled)
            return BugReportRobot()
        }
        
        @discardableResult
        func troubleshootButtonIsClicked() -> BugReportRobot {
            XCTAssertTrue(app.staticTexts[statusLabel].exists)
            return BugReportRobot()
        }
    }
}
