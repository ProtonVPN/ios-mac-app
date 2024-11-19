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

fileprivate let editButton = Localizable.edit
fileprivate let doneButton = Localizable.done
fileprivate let addButton = "Add"
fileprivate let deleteButton = Localizable.delete
fileprivate let newProfileSuccessMessage = Localizable.profileCreatedSuccessfully
fileprivate let editProfileSuccessMessage = Localizable.profileEditedSuccessfully
fileprivate let fastestProfile = Localizable.fastest
fileprivate let randomProfile = Localizable.random
fileprivate let myProfiles = Localizable.myProfiles

class ProfileRobot: CoreElements {
    
    let verify = Verify()

    @discardableResult
    func tapAddNewProfile() -> CreateProfileRobot {
        button(addButton).tap()
        return CreateProfileRobot()
    }

    @discardableResult
    func deleteProfile(_ profileName: String, _ countryname: String) -> ProfileRobot {
        button(editButton).tap()
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
    func connectToAFastestServer() -> HomeRobot {
        staticText(fastestProfile).tap()
        return HomeRobot()
    }

    @discardableResult
    func disconnectFromAFastestServer() -> HomeRobot {
        staticText(fastestProfile).tap()
        return HomeRobot()
    }

    @discardableResult
    func connectToARandomServer() -> HomeRobot {
        staticText(randomProfile).tap()
        return HomeRobot()
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
            return ProfileRobot()
        }
        
        @discardableResult
        func profileIsEdited(profile: String) -> ProfileRobot {
            staticText(editProfileSuccessMessage).checkExists()
            checkProfileExists(profile)
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
            return staticText()
                .containsLabel(profileName)
                .checkExists(message: "\(profileName) profile not found")
        }
    }
}
