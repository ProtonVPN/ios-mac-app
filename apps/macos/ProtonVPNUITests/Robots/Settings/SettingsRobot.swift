//
//  Created on 2022-01-12.
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

import Foundation
import XCTest
import Strings
import fusion
import UITestsHelpers

var window: XCUIElement!

fileprivate let preferencesTitleId = "Preferences"
fileprivate let generalTab = "General"
fileprivate let connectionTab = "Connection"
fileprivate let advancedTab = "Advanced"
fileprivate let accountTab = "Account"
fileprivate let modalTitle = "Allow LAN connections"
fileprivate let autoConnectFastest = "  Fastest"
fileprivate let notNowButton = "Not now"
fileprivate let continueButton = "Continue"
fileprivate let modalDescribtion = "In order to allow LAN access, Kill Switch must be turned off.\n\nContinue?"
fileprivate let modalUpgradeButton = "ModalUpgradeButton"
fileprivate let upsellModalTitle = "TitleLabel"
fileprivate let modalDescription = "DescriptionLabel"

class SettingsRobot: CoreElements {
    
    func generalTabClick() -> SettingsRobot {
        tabGroup(generalTab).tap()
        return SettingsRobot()
    }
    
    @discardableResult
    func connectionTabClick() -> SettingsRobot {
        tabGroup(connectionTab).tap()
        return SettingsRobot()
    }
    
    @discardableResult
    func advancedTabClick() -> SettingsRobot {
        tabGroup(advancedTab).tap()
        return SettingsRobot()
    }
    
    @discardableResult
    func accountTabClick() -> SettingsRobot {
        tabGroup(accountTab).tap()
        return SettingsRobot()
    }
    
    @discardableResult
    func notNowClick() -> SettingsRobot {
        button(notNowButton).tap()
        return SettingsRobot()
    }
    
    @discardableResult
    func continueClick() -> SettingsRobot {
        button(continueButton).tap()
        return SettingsRobot()
    }
    
    func closeSettings() -> MainRobot {
        windows(Localizable.preferences).typeKey("w", [.command])
        return MainRobot()
    }
    
    func selectAutoConnect(_ autoConnect: AutoConnectOptions) -> SettingsRobot {
        popUpButton(Localizable.autoConnect).onChild(popUpButton().firstMatch()).tap()
        let predicate = NSPredicate(format: "title CONTAINS[c] %@", autoConnect.rawValue)
        menuItem(predicate).tap()
        return SettingsRobot()
    }
    
    func selectQuickConnect(_ qc: String) -> SettingsRobot {
        popUpButton(Localizable.quickConnect).onChild(popUpButton().firstMatch()).tap()
        let predicate = NSPredicate(format: "title CONTAINS[c] %@", qc)
        menuItem(predicate).tap()
        return SettingsRobot()
    }
    
    func selectProtocol(_ connectionProtocol: ConnectionProtocol) -> SettingsRobot {
        popUpButton(Localizable.protocol).onChild(popUpButton().firstMatch()).tap()
        menuItem(connectionProtocol.rawValue).tap()

        if case .IKEv2 = connectionProtocol {
            button(Localizable.ikeDeprecationAlertContinueButtonTitle)
                .waitUntilExists(time: WaitTimeout.normal).tap()
        }
        return SettingsRobot()
    }
    
    func selectProfile(_ name: String) -> SettingsRobot {
        popUpButton(Localizable.quickConnect).onChild(popUpButton().firstMatch()).tap()
        menuItem(name).tap()
        return SettingsRobot()
    }
    
    let verify = Verify()
    
    class Verify: CoreElements {
                    
        @discardableResult
        func checkSettingsIsOpen() -> SettingsRobot {
            staticText(preferencesTitleId).checkExists()
            return SettingsRobot()
        }
        
        @discardableResult
        func checkProfileIsCreated(_ profileName: String) -> SettingsRobot {
            popUpButton(Localizable.quickConnect).onChild(popUpButton().firstMatch()).tap()
            menuItem(profileName).checkExists()
            // close Quick Connect dropdown
            popUpButton(Localizable.quickConnect).tap()
            return SettingsRobot()
        }
        
        @discardableResult
        func checkGeneralTabIsOpen() -> SettingsRobot {
            staticText(Localizable.startOnBoot).checkExists()
            return SettingsRobot()
        }
        
        @discardableResult
        func checkConnectionTabIsOpen() -> SettingsRobot {
            staticText(Localizable.autoConnect).checkExists()
            return SettingsRobot()
        }
        
        @discardableResult
        func checkAdvancedTabIsOpen() -> SettingsRobot {
            staticText(Localizable.troubleshootItemAltTitle).checkExists()
            return SettingsRobot()
        }
        
        @discardableResult
        func checkAccountTabIsOpen() -> SettingsRobot {
            staticText(Localizable.username).checkExists()
            return SettingsRobot()
        }
        
        @discardableResult
        func checkAccountTabUserName(username: String) -> SettingsRobot {
            staticText(username).checkExists()
            return SettingsRobot()
        }
        
        @discardableResult
        func checkAccountTabPlan(planName: String) -> SettingsRobot {
            staticText(planName).checkExists()
            return SettingsRobot()
        }
        
        @discardableResult
        func checkModalIsOpen() -> SettingsRobot {
            staticText(modalTitle).waitUntilExists(time: WaitTimeout.normal).checkExists()
            staticText(modalDescription).waitUntilExists(time: WaitTimeout.normal).checkExists()
            return SettingsRobot()
        }
        
        @discardableResult
        func checkLanIsOff() -> SettingsRobot {
            return SettingsRobot()
        }
        
        @discardableResult
        func checkLanIsOn() -> SettingsRobot {
            return SettingsRobot()
        }
        
        @discardableResult
        func checkUpsellModalIsOpen() -> QuickSettingsRobot {
            staticText(upsellModalTitle).checkExists()
            staticText(modalDescription).checkExists()
            button(modalUpgradeButton).checkEnabled()
            return QuickSettingsRobot()
        }
        
        @discardableResult
        func checkProtocolSelected(_ expectedProtocol: ConnectionProtocol) -> SettingsRobot {
            popUpButton(Localizable.protocol)
                .waitUntilExists(time: WaitTimeout.normal)
                .checkExists()
                .checkHasValue(expectedProtocol.rawValue)
            return SettingsRobot()
        }
        
        func checkAutoConnectSelected(_ expectedAutoConnectOption: AutoConnectOptions) -> SettingsRobot {
            popUpButton(Localizable.autoConnect)
                .waitUntilExists(time: WaitTimeout.normal)
                .checkExists()
                .checkContainsValue(expectedAutoConnectOption.rawValue)
            return SettingsRobot()
        }
    }
}
