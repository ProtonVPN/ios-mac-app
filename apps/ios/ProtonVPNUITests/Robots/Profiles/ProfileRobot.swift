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
    
    func tapAddNewProfile() -> CreateProfileRobot {
        button(addButton).tap()
        return CreateProfileRobot()
    }
    
    func deleteProfile(_ name: String, _ countryname: String) -> ProfileRobot {
        return delete(name, countryname)
    }
    
    func editProfile(_ name: String) -> CreateProfileRobot {
        edit(name)
        return CreateProfileRobot()
    }
    
    func connectToAProfile(_ profileName: String) -> ConnectionStatusRobot {
        staticText(NSPredicate(format: "label CONTAINS[c] %@", profileName))
            .checkExists(message: "\(profileName) profile not found").tap()
        return ConnectionStatusRobot()
    }
    
    func disconnectFromAProfile(_ profileName: String) -> ConnectionStatusRobot {
        staticText(NSPredicate(format: "label CONTAINS[c] %@", profileName))
            .checkExists(message: "\(profileName) profile not found").tap()
        return ConnectionStatusRobot()
    }
    
    func connectToAFastestServer() -> MainRobot {
        staticText(fastestProfile).tap()
        return MainRobot()
    }
    
    func disconnectFromAFastestServer() -> MainRobot {
        staticText(fastestProfile).tap()
        return MainRobot()
    }
    
    func connectToARandomServer() -> MainRobot {
        staticText(randomProfile).tap()
        return MainRobot()
    }
    
    func disconnectFromARandomServer() -> MainRobot {
        staticText(randomProfile).tap()
        return MainRobot()
    }
        
    private func delete(_ name: String, _ countryname: String) -> ProfileRobot {
        
        var deleteButtonText = "Delete"
        if #available(iOS 17.0, *) {
            deleteButtonText = "Remove"
        }
        button(editButton).tap()
        let deleteButtonPredicate = NSPredicate(format: "label CONTAINS[c] %@", name)
        button(deleteButtonPredicate).checkExists().tap()
        button(deleteButton).tap()
        return self
    }
    
    @discardableResult
    private func edit(_ name: String) -> ProfileRobot {
        button(editButton).tap()
        staticText().containsLabel(name).tap()
        return self
    }
    
    class Verify: CoreElements {
        
        func isOnProfilesScreen() -> ProfileRobot {
            staticText(myProfiles).checkExists(message: "Profiles screen is not visible")
            return ProfileRobot()
        }

        func profileIsDeleted(_ name: String, _ countryname: String) {
            button("Delete " + countryname + "    Fastest, " + name).checkDoesNotExist()
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
        private func checkProfileExists(_ name: String) -> UIElement {
            return staticText(NSPredicate(format: "label CONTAINS[c] %@", name))
                .checkExists(message: "\(name) profile not found")
        }
    }
}
