//
//  MainRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-05-28.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import fusion
import Strings
import UITestsHelpers

fileprivate let tabProfiles = Localizable.profiles
fileprivate let tabSettings = Localizable.settings
fileprivate let tabCountries = Localizable.countries
fileprivate let tabMap = Localizable.map
fileprivate let quickConnectButtonId = "quick connect inactive button"
fileprivate let quickDisconnectButtonId = "quick connect active button"
fileprivate let statusNotConnected = Localizable.notConnected
fileprivate let upgradeSubscriptionTitle = Localizable.modalsNewUpsellCountryTitle
fileprivate let upgradeSubscriptionButton = Localizable.upsellPlansListValidateButton
fileprivate let buttonOk = Localizable.ok
fileprivate let buttonCancel = Localizable.cancel
fileprivate let buttonAccount = Localizable.account
fileprivate let showLoginButtonLabelText = Localizable.logIn
fileprivate let showSignupButtonLabelText = Localizable.createAccount
fileprivate let upselModalId = "TitleLabel"

// MainRobot class contains actions for main app view.

class MainRobot: CoreElements {
    
    let verify = Verify()
    
    @discardableResult
    func goToCountriesTab() -> CountryListRobot {
        button(tabCountries).tap()
        return CountryListRobot()
    }
    
    @discardableResult
    func goToMapTab() -> MapRobot {
        button(tabMap).tap()
        return MapRobot()
    }
    
    @discardableResult
    func goToProfilesTab() -> ProfileRobot {
        button(tabProfiles).tap()
        return ProfileRobot()
    }

    @discardableResult
    func goToSettingsTab() -> SettingsRobot {
        button(tabSettings).waitUntilExists(time: 30).tap()
        return SettingsRobot()
    }
    
    func quickConnectViaQCButton() -> ConnectionStatusRobot {
        button(quickConnectButtonId).tap()
        return ConnectionStatusRobot()
    }
    
    func backToPreviousTab<T: CoreElements>(robot _: T.Type, _ name: String) -> T {
        button(name).byIndex(0).tap()
        return T()
    }
    
    @discardableResult
    func quickDisconnectViaQCButton() -> ConnectionStatusRobot {
        button(quickDisconnectButtonId).tap()
        return ConnectionStatusRobot()
    }
    
    @discardableResult
    public func showSignup() -> SignupRobot {
        button(showSignupButtonLabelText).waitUntilExists().tap()
        return SignupRobot()
    }
    
    @discardableResult
    public func showLogin() -> LoginRobot {
        button(showLoginButtonLabelText).waitUntilExists().tap()
        return LoginRobot()
    }

    class Verify: CoreElements {
    
        @discardableResult
        func qcButtonConnected() -> MainRobot {
            button(quickDisconnectButtonId).waitUntilExists().checkExists()
            return MainRobot()
        }
    
        @discardableResult
        func qcButtonDisconnected() -> MainRobot {
            button(quickConnectButtonId).waitUntilExists().checkExists()
            return MainRobot()
        }
    
        @discardableResult
        func connectionStatusNotConnected() -> MainRobot {
            staticText(statusNotConnected).waitUntilExists(time: 21).checkExists()
            return MainRobot()
        }
    
        @discardableResult
        func connectionStatusConnectedTo(_ name: String) -> MainRobot {
            staticText(name).waitUntilExists().checkExists()
            return MainRobot()
        }
    
        @discardableResult
        func upgradeSubscriptionScreenOpened() -> MainRobot {
            staticText(upgradeSubscriptionTitle).checkExists()
            button(upgradeSubscriptionButton).checkExists()
            return MainRobot()
        }
        
        @discardableResult
        func upsellModalIsOpen() -> MainRobot {
            staticText(upselModalId).checkExists()
            return MainRobot()
        }
    }
}
