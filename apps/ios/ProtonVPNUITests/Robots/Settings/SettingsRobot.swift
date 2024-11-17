//
//  SettingsRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-05-28.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import fusion
import XCTest
import UITestsHelpers
import Strings

fileprivate let headerTitle = Localizable.settingsTitle
fileprivate let protocolButton = Localizable.protocol
fileprivate let netshieldButton = Localizable.netshieldTitle
fileprivate let killSwitchButton = Localizable.killSwitch
fileprivate let allowLanConnectionsButton = Localizable.allowLanTitle
fileprivate let moderateNatSwitch = Localizable.moderateNatTitle
fileprivate let continueButton = Localizable.continue
fileprivate let logOutButton = Localizable.logOut
fileprivate let cancelButton = Localizable.cancel
fileprivate let firstAppScreen = "Selected environment"

class SettingsRobot: CoreElements {
    
    let verify = Verify()
    
    /// - Precondition: Protocol submenu of Settings menu
    @discardableResult
    func goToProtocolsList() -> ProtocolsListRobot {
        cell(protocolButton).firstMatch().tap()
        return ProtocolsListRobot()
    }
    
    /// - Precondition: Netshield submenu of Settings menu
    @discardableResult
    func goToNetshieldList() -> SettingsRobot {
        cell(netshieldButton).tap()
        return SettingsRobot()
    }

    @discardableResult
    func goToAccountDetail() -> AccountRobot {
        cell("Account Details cell").tap()
        return AccountRobot()
    }

    @discardableResult
    func selectNetshield(_ netshield: String) -> SettingsRobot {
        cell(netshieldButton).tap()
        staticText(netshield).tap()
        return SettingsRobot()
    }

    @discardableResult
    private func tapContinueIfExist() -> SettingsRobot {
        if button(continueButton).waitUntilExists(time: 0.5).exists() {
            button(continueButton).tap()
        }
        return self
    }


    @discardableResult
    func turnModerateNatOn() -> SettingsRobot {
        if let intValue = (swittch(moderateNatSwitch).value() as? String).flatMap({ Int($0) }), intValue == 0 {
            swittch(moderateNatSwitch).tap()
        }
        return SettingsRobot()
    }
    
    @discardableResult
    func turnKillSwitchOn() -> SettingsRobot {
        return killSwitchOn()
            .tapContinueIfExist()
    }

    @discardableResult
    func toggleKillSwitch(state: Bool) -> SettingsRobot {
        let currentState = (swittch(killSwitchButton)
            .swipeUpUntilVisible().value() as? String) == "1"
        if currentState != state {
            swittch(killSwitchButton).tap()
            tapContinueIfExist()
        }
        return self
    }

    @discardableResult
    func turnLanConnectionOn() -> SettingsRobot {
        return lanConnectionOn()
            .lanConnectionContinue()
    }
    
    @discardableResult
    func logOut() -> SettingsRobot {
        return clickLogOut().tapContinueIfExist()
    }
    
    @discardableResult
    func cancelLogOut() -> HomeRobot {
        return clickLogOut()
            .logOutCancel()
    }
    
    /// - Precondition: Kill Switch is off
    @discardableResult
    private func killSwitchOn() -> SettingsRobot {
        swittch(killSwitchButton)
            .swipeUpUntilVisible()
            .tap()
        return self
    }
    
    /// - Precondition: Lan Connection is off
    @discardableResult
    private func lanConnectionOn() -> SettingsRobot {
        swittch(allowLanConnectionsButton).tap()
        return self
    }
    
    @discardableResult
    private func lanConnectionContinue() -> SettingsRobot {
        button(continueButton).tap()
        return self
    }
    
    @discardableResult
    private func clickLogOut() -> SettingsRobot {
        button(logOutButton).swipeUpUntilVisible().tap()
        return self
    }
    
    @discardableResult
    private func logOutCancel() -> HomeRobot {
        button(cancelButton).tap()
        return HomeRobot()
    }
    
    class Verify: CoreElements {
        
        @discardableResult
        func bugReportFormIsClosed() -> SettingsRobot {
            staticText(headerTitle).waitUntilExists().checkExists()
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
            staticText(firstAppScreen).waitUntilExists().checkExists()
            return SettingsRobot()
        }
        
        @discardableResult
        func smartIsEnabled() -> SettingsRobot {
            staticText("Smart").checkExists()
            return SettingsRobot()
        }
        
        @discardableResult
        func stealthIsEnabled() -> SettingsRobot {
            staticText("Stealth").checkExists()
            return SettingsRobot()
        }
        
        @discardableResult
        func correctUserIsLoggedIn(_ userName: String, _ userPlan: String) -> SettingsRobot {
            staticText(userName)
                .waitUntilExists(time: WaitTimeout.short)
                .checkExists(message: "Username '\(userName)' is not visible")
            staticText(userPlan)
                .waitUntilExists(time: WaitTimeout.short)
                .checkExists(message: "User plan '\(userPlan)' is not visible")
            return SettingsRobot()
        }

        @discardableResult
        func correctUserIsLogedIn(_ user: Credentials) -> SettingsRobot {
            return correctUserIsLoggedIn(user.username, user.plan)
        }
    }
}
