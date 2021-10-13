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
        logInToProdIfNeeded()
    }
    
    func testSendBugReport() {
        
        let message = StringUtils().randomAlphanumericString(length: 10)
        let email = "testemail@automation.com"
        
        mainRobot
            .goToSettingsTab()
            .openReportBugWindow()
            .fillBugReportForm(email, message)
            .sendBugReport()
            .verify.bugReportIsSent()
            .closeBugReporForm()
            .verify.bugReporFormIsClosed()
    }
    
    func testSendBugReportWithInvalidEmail() {
        
        let message = StringUtils().randomAlphanumericString(length: 10)
        let email = "testemailautomation.com"
        
        mainRobot
            .goToSettingsTab()
            .openReportBugWindow()
            .fillBugReportForm(email, message)
            .sendBugReport()
            .verify.invalidEmailMessageIsShown()
    }
    
    func testSendBugReportWithShortMessage() {
        
        let message = StringUtils().randomAlphanumericString(length: 9)
        let email = "testemail@automation.com"
        
        mainRobot
            .goToSettingsTab()
            .openReportBugWindow()
            .fillBugReportForm(email, message)
            .sendBugReport()
            .verify.addMoreDetailsdMessagIsShown()
    }
}
