//
//  Created on 2022-02-03.
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

fileprivate let bugReportButton = "Bug report"
fileprivate let backButton = "Left"
// Step 1
fileprivate let stepOneTitle = "What's the issue?"
fileprivate let browsingSpeedIssue = "Browsing speed_"
fileprivate let usingTheAppIssue = "Using the app_"
fileprivate let somethingElseIssue = "Something else_"
// Step 2
fileprivate let stepTwoTitle = "Quick fixes"
fileprivate let stepTwoSubtitle = "These tips could help to solve your issue faster."
fileprivate let fixOne = "Log out and log back in."
fileprivate let fixTwo = "Restart the app."
fileprivate let fixThree = "Try a different server. Servers in nearby countries often have faster connection speeds."
fileprivate let contactUsButton = "Contact us"
// Step 3
fileprivate let emailTextField = "Single line input _email"
fileprivate let whatWentWrongTextField = "Multiline input What went wrong?"
fileprivate let networkTypeTextField = "Single line input Network type"
fileprivate let whatAreYouTringToDoTextField = "Multiline input What are you trying to do?"
fileprivate let whatIsTheSpeedTextField = "Single line input What is the speed you are getting?"
fileprivate let connectionSpeedTextField = "Single line input What is your connection speed without VPN?"
fileprivate let toggleLogs = "Toggle _logs"
fileprivate let logsWarning = "Error logs help us to get to the bottom of your issue. If you don’t include them, we might not be able to investigate fully."
fileprivate let sendReportButton = "Send report"
// Messages
fileprivate let successMessageTitle = "Thanks for your feedback"
fileprivate let errorMessageTitle = "Your report wasn’t sent"
fileprivate let gotItButton = "Got it"
fileprivate let tryAgainButton = "Try again"
fileprivate let troubleshootgButton = "Troubleshoot"
fileprivate let statusLabel = "statusLabel"

class BugReportRobot {
    
    func openBugReport() -> BugReportRobot {
        app.buttons[bugReportButton].click()
        return BugReportRobot()
    }
    
    func reportSomethingElseIssue() -> BugReportRobot {
        app.buttons[somethingElseIssue].click()
        return BugReportRobot()
    }
    
    func contactUs() -> BugReportRobot {
        app.buttons[contactUsButton].click()
        return BugReportRobot()
    }
    
    func reportUsingTheAppIssue() -> BugReportRobot {
        app.buttons[usingTheAppIssue].click()
        return BugReportRobot()
    }
    
    func reportBrowsingSpeedIssue() -> BugReportRobot {
        app.buttons[browsingSpeedIssue].click()
        return BugReportRobot()
    }
    
    func enterEmailAddress(_ email: String) -> BugReportRobot {
        app.textFields[emailTextField].click()
        app.textFields[emailTextField].typeText(email)
        return BugReportRobot()
    }
    
    func enterDescription(_ text: String) -> BugReportRobot {
        let textView = app.scrollViews[whatWentWrongTextField].children(matching: .textView).element
        textView.click()
        textView.typeText(text)
        return BugReportRobot()
    }
    
    func fillDetails(_ text: String) -> BugReportRobot {
        let whatAreYouTryingToDoTextField = app.scrollViews[whatAreYouTringToDoTextField].children(matching: .textView).element

        app.textFields[networkTypeTextField].click()
        app.textFields[networkTypeTextField].typeText(text)
        whatAreYouTryingToDoTextField.click()
        whatAreYouTryingToDoTextField.typeText(text)
        app.textFields[whatIsTheSpeedTextField].click()
        app.textFields[whatIsTheSpeedTextField].typeText(text)
        app.textFields[connectionSpeedTextField].click()
        app.textFields[connectionSpeedTextField].typeText(text)
        return BugReportRobot()
    }
    
    func sendBugReport() -> BugReportRobot {
        app.buttons[sendReportButton].click()
        return BugReportRobot()
    }
    
    func toggleSendLogs() -> BugReportRobot {
        app.switches[toggleLogs].click()
        XCTAssertTrue(app.staticTexts[logsWarning].exists)
        app.switches[toggleLogs].click()
        return BugReportRobot()
    }
    
    func backToPreviousScreen() -> BugReportRobot {
        app.buttons[backButton].click()
        return BugReportRobot()
    }
    
    func openTroubleshootScreen() -> BugReportRobot {
        app.buttons[troubleshootgButton].click()
        return BugReportRobot()
    }
    
    public let verify = Verify()
    
    class Verify {
        
        @discardableResult
        func reportAnIssueScreenIsShown() -> BugReportRobot {
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
            return BugReportRobot()
        }
        
        func browsingSpeedScreenIsShown() -> BugReportRobot {
            XCTAssertTrue(app.staticTexts[stepTwoTitle].exists)
            XCTAssertTrue(app.staticTexts[stepTwoSubtitle].exists)
            XCTAssertTrue(app.staticTexts[fixThree].exists)
            XCTAssertTrue(app.buttons[contactUsButton].isEnabled)
            return BugReportRobot()
        }
        
        @discardableResult
        func bugReportFormIsShown() -> BugReportRobot {
            XCTAssert(app.textFields[emailTextField].waitForExistence(timeout: 5))
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
            XCTAssert(app.staticTexts[successMessageTitle].waitForExistence(timeout: 6))
            XCTAssertTrue(app.buttons[gotItButton].isEnabled)
            app.buttons[gotItButton].tap()
            let status = app.staticTexts[statusLabel]
            XCTAssertEqual(status.value as! String, "Finished")
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
            let status = app.staticTexts[statusLabel]
            XCTAssertEqual(status.value as! String, "Troubleshooting")
            return BugReportRobot()
        }
    }
}
