//
//  HomeRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-05-28.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import fusion
import Strings
import UITestsHelpers

fileprivate let tabHome = Localizable.home
fileprivate let tabCountries = Localizable.countries
fileprivate let tabProfiles = Localizable.profiles
fileprivate let tabSettings = Localizable.settings
fileprivate let quickConnectButtonId = "connect_button"
fileprivate let quickDisconnectButtonId = "disconnect_button"
fileprivate let upgradeSubscriptionTitle = Localizable.modalsNewUpsellCountryTitle
fileprivate let upgradeSubscriptionButton = Localizable.upsellPlansListValidateButton
fileprivate let buttonOk = Localizable.ok
fileprivate let buttonCancel = Localizable.cancel
fileprivate let buttonAccount = Localizable.account
fileprivate let showLoginButtonLabelText = Localizable.logIn
fileprivate let showSignupButtonLabelText = "Create an account"
fileprivate let upselModalId = "TitleLabel"

// HomeRobot class contains actions for Home view.

class HomeRobot: ConnectionBaseRobot {

    let verify = Verify()

    @discardableResult
    func goToCountriesTab() -> CountryListRobot {
        button(tabCountries).tap()
        return CountryListRobot()
    }

    @discardableResult
    func goToHomeTab<T: CoreElements>(robot _: T.Type = ConnectionStatusRobot.self) -> T {
        button(tabHome).tap()
        return T()
    }

    @discardableResult
    func goToProfilesTab() -> ProfileRobot {
        button(tabProfiles).tap()
        return ProfileRobot()
    }

    @discardableResult
    func goToSettingsTab() -> SettingsRobot {
        button(tabSettings).tap()
        return SettingsRobot()
    }

    @discardableResult
    func quickConnectViaQCButton() -> ConnectionStatusRobot {
        button(quickConnectButtonId).firstMatch().tap()
        allowVpnPermission()
        return ConnectionStatusRobot()
    }

    @discardableResult
    func backToPreviousTab<T: CoreElements>(robot _: T.Type, _ name: String) -> T {
        button(name).byIndex(0).tap()
        return T()
    }

    @discardableResult
    func quickDisconnectViaQCButton() -> ConnectionStatusRobot {
        button(quickDisconnectButtonId).firstMatch().tap()
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

    public func isLoggedIn() -> Bool {
        return button(tabHome).waitUntilExists(time: 4).exists()
    }

    class Verify: CoreElements {

        @discardableResult
        func qcButtonConnected() -> HomeRobot {
            button(quickDisconnectButtonId).waitUntilExists().checkExists()
            return HomeRobot()
        }

        @discardableResult
        func qcButtonDisconnected() -> HomeRobot {
            button(quickConnectButtonId).waitUntilExists().checkExists()
            return HomeRobot()
        }

        @discardableResult
        func upgradeSubscriptionScreenOpened() -> HomeRobot {
            staticText(upgradeSubscriptionTitle).checkExists()
            button(upgradeSubscriptionButton).checkExists()
            return HomeRobot()
        }

        @discardableResult
        func upsellModalIsOpen() -> HomeRobot {
            staticText(upselModalId).checkExists()
            return HomeRobot()
        }

        @discardableResult
        func isLoggedIn() -> HomeRobot {
            button(tabHome)
                .waitUntilExists(time: 30)
                .checkExists(message: "Failed to check that user is logged in. Home tab is not visible in 30 seconds")
            return HomeRobot()
        }
    }
}
