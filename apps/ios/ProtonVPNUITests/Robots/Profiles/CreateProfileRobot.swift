//
//  CreateProfileRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-05-18.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import PMTestAutomation

fileprivate let profilesNavigationBar = "Create Profile"
fileprivate let profileSameName = "Profile with same name already exists"
fileprivate let nameField = "Enter Profile Name"
fileprivate let countryField = "Select Country"
fileprivate let serverField = "Select Server"
fileprivate let fastesServer = "  Fastest"
fileprivate let saveProfileButton = "Save"
fileprivate let tabBars = "Profiles"
fileprivate let secureCoreToggle = "Secure Core"
fileprivate let defaultprofileToggle = "Make Default Profile"
fileprivate let subscribtionRequired = "Plus or Visionary subscription required"
fileprivate let okButton = "OK"

class CreateProfileRobot: CoreElements {
    
    let verify = Verify()
    
    func setProfileDetails(_ name: String, _ countryname: String) -> CreateProfileRobot {
        return enterProfileName(name)
            .selectCountry()
            .chooseCountry(" " + " " + countryname)
            .selectServer()
            .chooseServer()
    }
    
    func setProfileWithSameName(_ name: String, _ countryname: String)-> CreateProfileRobot {
        return enterProfileName(name)
            .selectCountry()
            .chooseCountry(" " + " " + countryname)
            .selectServer()
            .chooseServer()
    }
    
    func makeDefaultProfileWithSecureCore(_ name: String, _ countryname: String, _ server: String) -> CreateProfileRobot {
        return enterProfileName(name)
            .secureCoreON()
            .selectCountry()
            .chooseCountry(" " + " " + countryname)
            .selectServer()
            .chooseServerVia(server)
            .defaultProfileON()
    }
    
    func setSecureCoreProfile(_ name: String)-> CreateProfileRobot {
        return enterProfileName(name)
            .secureCoreON()
    }
    
    func saveProfile<T: CoreElements>(robot _: T.Type) -> T {
        button(saveProfileButton).tap()
        return T()
    }
    
    private func enterProfileName(_ name: String) -> CreateProfileRobot {
        textField(nameField).tap().typeText(name)
        return self
    }
    
    private func selectCountry() -> CreateProfileRobot {
        staticText(countryField).tap()
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
        swittch(defaultprofileToggle).tap()
        return self
    }
    
    class Verify: CoreElements {
        
        @discardableResult
        func profileWithSameName() -> CreateProfileRobot{
            staticText(profileSameName).checkExists()
            return CreateProfileRobot()
        }
        
        @discardableResult
        func subscribtionRequiredMessage() -> CreateProfileRobot{
            staticText(subscribtionRequired).checkExists()
            return CreateProfileRobot()
        }
    }
}
