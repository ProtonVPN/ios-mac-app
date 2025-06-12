//
//  ProfileRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-05-18.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import fusion
import Foundation
import Strings
import UITestsHelpers

private let editButton = Localizable.edit
private let doneButton = Localizable.done
private let addButton = "Add"
private let deleteButton = Localizable.delete
private let newProfileSuccessMessage = Localizable.profileCreatedSuccessfully
private let editProfileSuccessMessage = Localizable.profileEditedSuccessfully
private let fastestProfile = Localizable.fastest
private let randomProfile = Localizable.random
private let myProfiles = Localizable.myProfiles

class ProfileRobot: ConnectionBaseRobot {
    let verify = Verify()
    
    @discardableResult
    func tapAddNewProfile() -> CreateProfileRobot {
        button(addButton).tap()
        return CreateProfileRobot()
    }
    
    @discardableResult
    func deleteProfile(_ profileName: String) -> ProfileRobot {
        button(editButton).waitForEnabled(time: WaitTimeout.short).tap()
        if !button(doneButton)
            .waitUntilExists(time: WaitTimeout.short)
            .exists() {
            button(editButton).tap()
        }
        button()
            .containsLabel(profileName)
            .swipeUpUntilVisible()
            .checkExists()
            .tap()
        button(deleteButton).tap()
        return self
    }
    
    @discardableResult
    func editProfile(_ profileName: String) -> CreateProfileRobot {
        edit(profileName)
        return CreateProfileRobot()
    }
    
    @discardableResult
    func connectToAProfile(_ profileName: String) -> ConnectionStatusRobot {
        staticText().containsLabel(profileName)
            .checkExists(message: "\(profileName) profile not found").forceTap()
        allowVpnPermission()
        return ConnectionStatusRobot()
    }
    
    @discardableResult
    func disconnectFromAProfile(_ profileName: String) -> ConnectionStatusRobot {
        staticText()
            .containsLabel(profileName)
            .checkExists(message: "\(profileName) profile not found").tap()
        return ConnectionStatusRobot()
    }
    
    @discardableResult
    func connectToAFastestServer() -> ConnectionStatusRobot {
        staticText(fastestProfile).tap()
        allowVpnPermission()
        return ConnectionStatusRobot()
    }
    
    @discardableResult
    func disconnectFromAFastestServer() -> HomeRobot {
        staticText(fastestProfile).tap()
        return HomeRobot()
    }
    
    @discardableResult
    func connectToARandomServer() -> ConnectionStatusRobot {
        staticText(randomProfile).tap()
        allowVpnPermission()
        return ConnectionStatusRobot()
    }
    
    @discardableResult
    func disconnectFromARandomServer() -> HomeRobot {
        staticText(randomProfile).tap()
        return HomeRobot()
    }
    
    @discardableResult
    private func edit(_ profileName: String) -> ProfileRobot {
        button(editButton).tap()
        staticText().containsLabel(profileName).tap()
        return self
    }
    
    class Verify: CoreElements {
        @discardableResult
        func isOnProfilesScreen() -> ProfileRobot {
            staticText(myProfiles).checkExists(message: "Profiles screen is not visible")
            return ProfileRobot()
        }
        
        func profileIsDeleted(_ profileName: String) {
            button()
                .containsLabel(profileName)
                .checkDoesNotExist()
            staticText().containsLabel(profileName).checkDoesNotExist()
        }
        
        @discardableResult
        func profileIsCreated(profile: String) -> ProfileRobot {
            staticText(newProfileSuccessMessage).checkExists()
            checkProfileExists(profile)
            staticText(newProfileSuccessMessage).waitUntilGone()
            return ProfileRobot()
        }
        
        @discardableResult
        func profileIsEdited(profile: String) -> ProfileRobot {
            staticText(editProfileSuccessMessage).checkExists()
            checkProfileExists(profile)
            staticText(editProfileSuccessMessage).waitUntilGone()
            return ProfileRobot()
        }
        
        @discardableResult
        func recommendedProfilesAreVisible() -> ProfileRobot {
            staticText(fastestProfile).checkExists()
            staticText(randomProfile).checkExists()
            return ProfileRobot()
        }
        
        @discardableResult
        private func checkProfileExists(_ profileName: String) -> UIElement {
            staticText()
                .containsLabel(profileName)
                .checkExists(message: "\(profileName) profile not found")
        }
    }
}
