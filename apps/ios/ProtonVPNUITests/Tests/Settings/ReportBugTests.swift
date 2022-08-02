//
//  ReportBugTests.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-05-28.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

// NavigationService.presentReportBug() checks if UI tests are being run, and if yes, uses old ReportBug screen, wchich is tested here.
// New ReportBug screens are tested separately in SampleApps/BugReportSampleMacOSApp and SampleApps/BugReportSampleiOSApp.

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
            .closeBugReportForm()
            .verify.bugReportFormIsClosed()
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
            .verify.addMoreDetailsMessageIsShown()
    }
}
