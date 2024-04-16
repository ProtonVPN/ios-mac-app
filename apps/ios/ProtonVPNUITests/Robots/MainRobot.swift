//
//  MainRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-05-28.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import fusion

fileprivate let tabProfiles = "Profiles"
fileprivate let tabSettings = "Settings"
fileprivate let tabCountries = "Countries"
fileprivate let tabMap = "Map"
fileprivate let tabQCInactive = "quick connect inactive button"
fileprivate let tabQCActive = "quick connect active button"
fileprivate let secureCore = "Use Secure Core"
fileprivate let statusNotConnected = "Not Connected"
fileprivate let upgradeSubscriptionTitle = "Upgrade"
fileprivate let buttonOk = "OK"
fileprivate let buttonCancel = "Cancel"
fileprivate let buttonAccount = "Account"
fileprivate let environmentText = "https://vpn-api.proton.me"
fileprivate let useAndContinueButton = "Use and continue"
fileprivate let resetToProductionButton = "Reset to production and kill the app"
fileprivate let showLoginButtonLabelText = "Sign in"
fileprivate let showSignupButtonLabelText = "Create an account"
fileprivate let upselModal = "TitleLabel"

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
        button(tabQCInactive).tap()
        return ConnectionStatusRobot()
    }
    
    func backToPreviousTab<T: CoreElements>(robot _: T.Type, _ name: String) -> T {
        button(name).byIndex(0).tap()
        return T()
    }
    
    @discardableResult
    func quickDisconnectViaQCButton() -> ConnectionStatusRobot {
        button(tabQCActive).tap()
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
    
    func clickUpgrade() -> MainRobot {
        button(upgradeSubscriptionTitle).tap()
        return MainRobot()
    }
    
    // Temporary solution. This modal will be removed soon
    func dismissWhatsNewModal() -> MainRobot {
        let buttonText = "Got it!"
        if button(buttonText).waitUntilExists(time: 30).exists() {
            button(buttonText).tap()
        } else {
            button(tabSettings).tap()
        }
        return MainRobot()
    }
    
    class Verify: CoreElements {
    
        @discardableResult
        func qcButtonConnected() -> MainRobot {
            button(tabQCActive).waitUntilExists().checkExists()
            return MainRobot()
        }
    
        @discardableResult
        func qcButtonDisconnected() -> MainRobot {
            button(tabQCInactive).waitUntilExists().checkExists()
            return MainRobot()
        }
    
        @discardableResult
        func connectionStatusNotConnected() -> MainRobot {
            staticText(statusNotConnected).waitUntilExists(time: 20).checkExists()
            return MainRobot()
        }
    
        @discardableResult
        func connectionStatusConnectedTo(_ name: String) -> MainRobot {
            staticText(name).waitUntilExists().checkExists()
            return MainRobot()
        }
    
        @discardableResult
        func upgradeSubscriptionIsOpenFreeUser() -> MainRobot {
            staticText(upgradeSubscriptionTitle).checkExists()
            return MainRobot()
        }
        
        @discardableResult
        func upsellModalIsOpen() -> MainRobot {
            staticText(upselModal).checkExists()
            return MainRobot()
        }
    }
}
