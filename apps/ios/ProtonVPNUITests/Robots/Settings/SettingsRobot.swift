//
//  SettingsRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-05-28.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import pmtest
import XCTest

fileprivate let headerTitle = "Settings"
fileprivate let reportBugtButton = "Report Bug"
fileprivate let protocolButton = "Protocol"
fileprivate let killSwitchButton = "Kill Switch"
fileprivate let killSwitchAlert = "Turn Kill Switch on?"
fileprivate let allowLanConnectionsButton = "Allow LAN connections"
fileprivate let allowLanConnectionsAlert = "Allow LAN connections"
fileprivate let continueButton = "Continue"
fileprivate let logOutButton = "Log Out"
fileprivate let vpnConnectionActiveAlert = "VPN Connection Active"
fileprivate let firstAppScreen = "Selected environment"

class SettingsRobot: CoreElements {
    
    let verify = Verify()
    
    func openReportBugWindow() -> ReportBugRobot {
        button(reportBugtButton).tap()
        return ReportBugRobot()
    }
    
    func goToProtocolsList() -> ProtocolsListRobot {
        cell(protocolButton).tap()
        return ProtocolsListRobot()
    }
    
    func turnKillSwitchOn() -> SettingsRobot {
        return killSwitchOn()
            .killSwitchContinue()
    }
    
    func turnLanConnectionOn() -> SettingsRobot {
        return lanConnectionOn()
            .lanConnectionContinue()
    }
    
    func logOut() -> SettingsRobot {
        return clickLogOut()
            .logOutContinue()
    }
    
    private func killSwitchOn() -> SettingsRobot {
        XCUIApplication().swipeUp()
        swittch(killSwitchButton).tap()
        return self
    }
    
    private func killSwitchContinue() -> SettingsRobot {
        button(continueButton).tap()
        return self
    }
    
    private func lanConnectionOn() -> SettingsRobot {
        swittch(allowLanConnectionsButton).tap()
        return self
    }
    
    private func lanConnectionContinue() -> SettingsRobot {
        button(continueButton).tap()
        return self
    }
    
    private func clickLogOut() -> SettingsRobot {
        button(logOutButton).tap()
        return self
    }
    
    private func logOutContinue() -> SettingsRobot {
        button(continueButton).tap()
        return self
    }
    
    class Verify: CoreElements {
        
        @discardableResult
        func bugReporFormIsClosed() -> SettingsRobot {
            staticText(headerTitle).wait().checkExists()
            return SettingsRobot()
        }
        
        @discardableResult
        func ksIsEnabled() -> SettingsRobot {
            swittch(killSwitchButton).checkHasValue("1")
            swittch(allowLanConnectionsButton).checkHasValue("0")
            return SettingsRobot()
        }
        
        @discardableResult
        func lanConnectionIsEnabled() -> SettingsRobot {
            swittch(killSwitchButton).checkHasValue("0")
            swittch(allowLanConnectionsButton).checkHasValue("1")
            return SettingsRobot()
        }
        
        @discardableResult
        func logOutSuccessfully() -> SettingsRobot {
            staticText(firstAppScreen).wait().checkExists()
            return SettingsRobot()
        }
        
        @discardableResult
        func smartIsEnabled() -> SettingsRobot {
            staticText("Smart").checkExists()
            return SettingsRobot()
        }
        
        @discardableResult
        func ikeIsEnabled() -> SettingsRobot {
            staticText("IKEv2").checkExists()
            return SettingsRobot()
        }
        
        @discardableResult
        func userIsCreated(_ name: String, _ plan: String) -> SettingsRobot {
            staticText(name).checkExists()
            staticText(plan).checkExists()
            return SettingsRobot()
        }
    }
}
