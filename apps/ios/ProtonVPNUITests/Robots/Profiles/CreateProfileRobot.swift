//
//  CreateProfileRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-05-18.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import fusion

fileprivate let profileSameName = "Profile with same name already exists"
fileprivate let nameField = "Enter Profile Name"
fileprivate let countryField = "Select Country"
fileprivate let countryButton = "Country"
fileprivate let serverField = "Select Server"
fileprivate let fastestServer = "  Fastest"
fileprivate let protocolUDP = "OpenVPN (UDP)"
fileprivate let protocolWG = "WireGuard"
fileprivate let saveProfileButton = "Save"
fileprivate let tabBars = "Profiles"
fileprivate let secureCoreToggle = "Secure Core"
fileprivate let defaultProfileToggle = "Make Default Profile"
fileprivate let okButton = "OK"
fileprivate let protocolCell = "Protocol"
fileprivate let upgradeButton = "Upgrade"
fileprivate let notNowButton = "Not now"

class CreateProfileRobot: CoreElements {
    
    let verify = Verify()
    
    func setProfileDetails(_ name: String, _ countryname: String) -> CreateProfileRobot {
        return enterProfileName(name)
            .selectCountry()
            .chooseCountry(" " + " " + countryname)
            .selectServer()
            .chooseServer()
            .chooseProtocol()
    }
    
    func setProfileWithSameName(_ name: String, _ countryname: String) -> CreateProfileRobot {
        return enterProfileName(name)
            .selectCountry()
            .chooseCountry(" " + " " + countryname)
            .selectServer()
            .chooseServer()
    }
    
    func editProfileDetails(_ newname: String, _ countryname: String, _ newcountryname: String) -> CreateProfileRobot {
        return editProfileName(newname)
            .editCountry("  " + countryname)
            .chooseCountry(" " + " " + newcountryname)
            .selectServer()
            .chooseServer()
    }
    
    func makeDefaultProfileWithSecureCore(_ name: String, _ newcountryname: String, _ server: String) -> CreateProfileRobot {
        return enterProfileName(name)
            .secureCoreON()
            .selectCountry()
            .chooseCountry(" " + " " + newcountryname)
            .selectServer()
            .chooseServerVia(server)
            .chooseProtocol()
            .defaultProfileON()
    }
    
    func setSecureCoreProfile(_ name: String) -> CreateProfileRobot {
        return enterProfileName(name)
            .secureCoreON()
    }
    
    func setDefaultProfile(_ name: String, _ countryname: String) -> CreateProfileRobot {
        return enterProfileName(name)
            .selectCountry()
            .chooseCountry(countryname)
            .selectServer()
            .chooseServer()
            .defaultProfileON()
    }
    
    func saveProfile<T: CoreElements>(robot _: T.Type) -> T {
        button(saveProfileButton).tap()
        return T()
    }
    
    private func enterProfileName(_ name: String) -> CreateProfileRobot {
        textField(nameField).tap()
        textField(nameField).tap().typeText(name)
        return self
    }
    
    private func editProfileName(_ name: String) -> CreateProfileRobot {
        textField(name).tap()
        textField(name).tap().typeText("edit_")
        return self
    }
    
    private func selectCountry() -> CreateProfileRobot {
        staticText(countryField).tap()
        return self
    }
    
    private func editCountry(_ country: String) -> CreateProfileRobot {
        staticText(country).tap()
        return self
    }
    
    private func chooseCountry(_ countryname: String) -> CreateProfileRobot {
        staticText(countryname).tap()
        return self
    }
    
    private func selectServer() -> CreateProfileRobot {
        staticText(serverField).tap()
        return self
    }
    
    private func chooseServer() -> CreateProfileRobot {
        cell().byIndex(0).tap()
        return self
    }
    
    private func chooseServerVia(_ server: String) -> CreateProfileRobot {
        staticText("via    " + server).tap()
        return self
    }
    
    private func secureCoreON() -> CreateProfileRobot {
        swittch(secureCoreToggle).tap()
        return self
    }
    
    private func defaultProfileON() -> CreateProfileRobot {
        swittch(defaultProfileToggle).tap()
        return self
    }
    
    private func chooseProtocol() -> CreateProfileRobot {
        cell(protocolCell).byIndex(1).tap()
        staticText(protocolWG).tap()
        return self
    }
    
    class Verify: CoreElements {

        @discardableResult
        func profileWithSameName() -> CreateProfileRobot {
            staticText(profileSameName).checkExists()
            return CreateProfileRobot()
        }
    }
}
