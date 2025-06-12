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

private let tabHome = Localizable.home
private let tabCountries = Localizable.countries
private let tabProfiles = Localizable.profiles
private let tabSettings = Localizable.settings
private let quickConnectButtonId = "connect_button"
private let quickDisconnectButtonId = "disconnect_button"
private let upgradeSubscriptionTitle = Localizable.modalsNewUpsellCountryTitle
private let upgradeSubscriptionButton = Localizable.upsellPlansListValidateButton
private let buttonOk = Localizable.ok
private let buttonCancel = Localizable.cancel
private let buttonAccount = Localizable.account
private let showLoginButtonLabelText = Localizable.logIn
private let showSignupButtonLabelText = "Create an account"
private let upselModalId = "TitleLabel"
private let connectionInfo = "connection_info"
private let okButtonId = "OK"

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
        return button(tabSettings).waitUntilExists(time: 4).exists()
    }

    public func openConnectionDetails() -> ConnectionDetailsRobot {
        button(connectionInfo).tap()
        return ConnectionDetailsRobot()
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
            button(tabSettings)
                .waitUntilExists(time: 30)
                .checkExists(message: "Failed to check that user is logged in. Settings tab is not visible in 30 seconds")
            if button(okButtonId).exists() {
                button(okButtonId).tap()
            }
            return HomeRobot()
        }

        @discardableResult
        func isOnHomeScreen() -> HomeRobot {
            button(tabHome)
                .checkExists(message: "Home screen is not visible")
            return HomeRobot()
        }
    }
}
