//
//  MainRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-05-28.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import pmtest


fileprivate let tabProfiles = "Profiles"
fileprivate let tabSettings = "Settings"
fileprivate let tabCountries = "Countries"
fileprivate let tabMap = "Map"
fileprivate let tabQCInactive = "quick connect inactive button"
fileprivate let tabQCActive = "quick connect active button"
fileprivate let secureCore = "Use Secure Core"
fileprivate let statusNotConnected = "Not Connected"
fileprivate let upgradeSubscribtionTitle = "Upgrade Subscription"
fileprivate let popUpforFreeUser = "Plus or Visionary subscription required"
fileprivate let popUpforBasicUser = "Upgrade Unavailable in App"
fileprivate let buttonOk = "OK"
fileprivate let buttonCancel = "Cancel"
fileprivate let buttonAccount = "Account"
fileprivate let environmentText = "https://api.protonvpn.ch"
fileprivate let showLoginButtonLabelText = "Sign in"
fileprivate let showSignupButtonLabelText = "Create an account"

// MainRobot class contains actions for main app view.

class MainRobot: CoreElements {
    
    let verify = Verify()
    
    func goToCountriesTab() -> CountryListRobot {
        button(tabCountries).tap()
        return CountryListRobot()
    }
    
    func goToMapTab() -> MapRobot {
        button(tabMap).tap()
        return MapRobot()
    }
    
    func goToProfilesTab() -> ProfileRobot {
        button(tabProfiles).tap()
        return ProfileRobot()
    }

    func goToSettingsTab() -> SettingsRobot {
        button(tabSettings).tap()
        return SettingsRobot()
    }
    
    func quickConnectViaQCbutton() -> ConnectionStatusRobot {
        button(tabQCInactive).tap()
        return ConnectionStatusRobot()
    }
    
    func backToPreviouseTab<T: CoreElements>(robot _: T.Type, _ name: String) -> T {
        button(name).byIndex(0).tap()
        return T()
    }
    
    @discardableResult
    func quickDisconnectViaQCbutton() -> ConnectionStatusRobot {
        button(tabQCActive).tap()
        return ConnectionStatusRobot()
    }
    
    @discardableResult
    public func showSignup() -> NewSignupRobot {
        button(showSignupButtonLabelText).wait().tap()
        return NewSignupRobot()
    }

    @discardableResult
     public func changeEnvironmentTo() -> MainRobot {
        staticText(environmentText).wait().tap()
         return self
     }
    
    @discardableResult
    public func showLogin() -> NewLoginRobot {
        button(showLoginButtonLabelText).wait().tap()
        return NewLoginRobot()
    }
    
    class Verify: CoreElements {
    
        @discardableResult
        func qcButtonConnected() -> MainRobot {
            button(tabQCActive).wait().checkExists()
            return MainRobot()
        }
    
        @discardableResult
        func qcButtonDisconnected() -> MainRobot {
            button(tabQCInactive).wait().checkExists()
            return MainRobot()
        }
    
        @discardableResult
        func connectionStatusNotConnected() -> MainRobot {
            staticText(statusNotConnected).wait().checkExists()
            return MainRobot()
        }
    
        @discardableResult
        func connectionStatusConnectedTo(_ name: String) -> MainRobot {
            staticText(name).wait().checkExists()
            return MainRobot()
        }
    
        @discardableResult
        func upgradeSubscribtionIsOpenFreeUser() -> MainRobot {
            staticText(upgradeSubscribtionTitle).checkExists()
            return MainRobot()
        }
    
        @discardableResult
        func upgradeSubscribtionIsOpenBasicUser() -> MainRobot {
            staticText(popUpforBasicUser).checkExists()
            return MainRobot()
        }
    }
}
