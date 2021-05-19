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
fileprivate let saveProfile = "Save"
fileprivate let tabBars = "Profiles"

class CreateProfileRobot: CoreElements {
    
    let verify = Verify()
    
    func setProfileDetails(_ name: String, _ countryname: String) -> CreateProfileRobot {
        return enterProfileName(name)
            .enterCountry()
            .chooseCountry(" " + " " + countryname)
            .enterServer()
            .chooseServer()
    }
    
    func setProfileWithSameName(_ name: String, _ countryname: String)-> CreateProfileRobot {
        return enterProfileName(name)
            .enterCountry()
            .chooseCountry(" " + " " + countryname)
            .enterServer()
            .chooseServer()
    }
    
    func saveProf<T: CoreElements>(robot _: T.Type) -> T {
        button(saveProfile).tap()
        return T()
    }
    
    private func enterProfileName(_ name: String) -> CreateProfileRobot {
        textField(nameField).tap().typeText(name)
        return self
    }
    
    private func enterCountry() -> CreateProfileRobot {
        staticText(countryField).tap()
        return self
    }
    
    private func chooseCountry(_ countryname: String) -> CreateProfileRobot {
        staticText(countryname).tap()
        return self
    }
    
    private func enterServer() -> CreateProfileRobot {
        staticText(serverField).tap()
        return self
    }
    
    private func chooseServer() -> CreateProfileRobot {
        cell().byIndex(0).tap()
        return self
    }
    
    class Verify: CoreElements {
        
        @discardableResult
        func profileWithSameName() -> CreateProfileRobot{
            staticText(profileSameName).checkExists()
            return CreateProfileRobot()
        }
    }
}
