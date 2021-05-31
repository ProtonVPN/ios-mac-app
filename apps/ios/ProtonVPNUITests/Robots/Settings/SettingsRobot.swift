//
//  SettingsRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-05-28.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import PMTestAutomation

fileprivate let headerTitle = "Settings"
fileprivate let reportBugtButton = "Report Bug"

class SettingsRobot: CoreElements {
    
    let verify = Verify()
    
    func openReportBugWindow() -> ReportBugRobot {
        button(reportBugtButton).tap()
        return ReportBugRobot()
    }
    
    class Verify: CoreElements {
        
        @discardableResult
        func bugReporFormIsClosed() -> SettingsRobot {
            staticText(headerTitle).wait().checkExists()
            return SettingsRobot()
        }
    }
}
