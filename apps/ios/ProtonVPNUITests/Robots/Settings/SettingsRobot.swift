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
fileprivate let reportBugButton = "Report Bug"
fileprivate let protocolButton = "Protocol"
fileprivate let netshieldButton =  "NetShield"
fileprivate let killSwitchButton = "Kill switch"
fileprivate let killSwitchAlert = "Turn kill switch on?"
fileprivate let allowLanConnectionsButton = "Allow LAN connections"
fileprivate let allowLanConnectionsAlert = "Allow LAN connections"
fileprivate let moderateNatSwitch = "Moderate NAT"
fileprivate let continueButton = "Continue"
fileprivate let logOutButton = "Log Out"
fileprivate let cancelButton = "Cancel"
fileprivate let vpnConnectionActiveAlert = "VPN Connection Active"
fileprivate let firstAppScreen = "Selected environment"

class SettingsRobot: CoreElements {
    
    let verify = Verify()
    
    func openReportBugWindow() -> ReportBugRobot {
        button(reportBugButton).tap()
        return ReportBugRobot()
    }
    
    /// - Precondition: Protocol submenu of Settings menu
    func goToProtocolsList() -> ProtocolsListRobot {
        cell(protocolButton).tap()
        return ProtocolsListRobot()
    }
    
    /// - Precondition: Netshield submenu of Settings menu
    func goToNetshieldList() -> SettingsRobot {
        cell(netshieldButton).tap()
        return SettingsRobot()
    }

    func selectNetshield(_ netshield: String) -> SettingsRobot {
        cell(netshieldButton).tap()
        staticText(netshield).tap()
        return SettingsRobot()
    }

    @discardableResult
    func turnModerateNatOn() -> SettingsRobot {
        swittch(moderateNatSwitch).tap()
        return SettingsRobot()
    }
    
    @discardableResult
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
    
    func cancelLogOut() -> ConnectionStatusRobot {
        return clickLogOut()
            .logOutCancel()
    }
    
    /// - Precondition: Kill Switch is off
    private func killSwitchOn() -> SettingsRobot {
        swittch(killSwitchButton)
            .swipeUpUntilVisible()
            .tap()
        return self
    }
    
    private func killSwitchContinue() -> SettingsRobot {
        button(continueButton).tap()
        return self
    }
    
    /// - Precondition: Lan Connection is off
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
    
    private func logOutCancel() -> ConnectionStatusRobot {
        button(cancelButton).tap()
        return ConnectionStatusRobot()
    }
    
    class Verify: CoreElements {
        
        @discardableResult
        func bugReportFormIsClosed() -> SettingsRobot {
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
