//
//  ReportBugTests.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-05-28.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

class ReportBugTests: ProtonVPNUITests {
    
    private let mainRobot = MainRobot()
    private let reportBugRobot = ReportBugRobot()
    private let settingsRobot = SettingsRobot()
    
    override func setUp() {
        super.setUp()
    }
    
    func testSendBugReportVisionaryUser() {
        
        let message = StringUtils().randomAlphanumericString(length: 201)
        let email = "testemail@automation.com"
        
        loginAsVisionaryUser()
        mainRobot
            .goToSettingsTab()
            .openReportBugWindow()
            .fillBugReportForm(email, message)
            .sendBugReport()
            .verify.bugReportIsSent()
            .closeBugReporForm()
            .verify.bugReporFormIsClosed()
    }
    
    func testSendBugReportWithInvalidEmailBasicUser() {
        
        let message = StringUtils().randomAlphanumericString(length: 201)
        let email = "testemailautomation.com"
        
        loginAsBasicUser()
        mainRobot
            .goToSettingsTab()
            .openReportBugWindow()
            .fillBugReportForm(email, message)
            .sendBugReport()
            .verify.errorMessageIsShown()
    }
}
