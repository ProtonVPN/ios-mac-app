//
//  ProfileRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-05-18.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import pmtest

fileprivate let editButton = "Edit"
fileprivate let doneButton = "Done"
fileprivate let addButton = "Add"
fileprivate let deleteButton = "Delete"
fileprivate let newProfileSuccessMessage = "New Profile saved"
fileprivate let editProfileSuccessMessage = "Profile updated"
fileprivate let buttonConnect = "ic power off"
fileprivate let buttonDisconnect = "ic power off"
fileprivate let fastestProfile = "Fastest Connection"
fileprivate let randomProfile = "Random Connection"

class ProfileRobot: CoreElements {
    
    let verify = Verify()
    
    @discardableResult
    func addNewProfile() -> CreateProfileRobot {
        return addNew()
    }
    
    func deleteProfile(_ name: String, _ countryname: String) -> ProfileRobot {
        return delete(name, countryname)
    }
    
    func editProfile(_ name: String) -> CreateProfileRobot {
        edit(name)
        return CreateProfileRobot()
    }
    
    func connectToAProfile(_ name: String) -> ConnectionStatusRobot {
        button(buttonConnect).byIndex(2).tap()
        return ConnectionStatusRobot()
    }
    
    func disconnectFromAProfile() -> MainRobot {
        button(buttonDisconnect).byIndex(2).tap()
        return MainRobot()
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
    
    private func addNew() -> CreateProfileRobot {
        button(addButton).tap()
        return CreateProfileRobot()
    }
        
    private func delete(_ name: String, _ countryname: String) -> ProfileRobot {
        button(editButton).tap()
        button("Delete " + countryname + "    Fastest, " + name).tap()
        button(deleteButton).tap()
        return self
    }
    
    @discardableResult
    private func edit(_ name: String) -> ProfileRobot {
        button(editButton).tap()
        staticText(name).tap()
        return self
    }
    
    class Verify: CoreElements {
        
        func profileIsDeleted(_ name: String, _ countryname: String) {
            button("Delete " + countryname + "    Fastest, " + name).checkDoesNotExist()
        }
        
        @discardableResult
        func profileIsCreated() -> ProfileRobot {
            staticText(newProfileSuccessMessage).checkExists()
            return ProfileRobot()
        }
        
        @discardableResult
        func profileIsEdited() -> ProfileRobot {
            staticText(editProfileSuccessMessage).checkExists()
            return ProfileRobot()
        }
        
        @discardableResult
        func recommendedProfilesAreVisible() -> ProfileRobot {
            staticText(fastestProfile).checkExists()
            staticText(randomProfile).checkExists()
            return ProfileRobot()
        }
    }
}

