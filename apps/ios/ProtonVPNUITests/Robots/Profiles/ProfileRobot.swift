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
fileprivate let successMessage = "New Profile saved"

class ProfileRobot: CoreElements {
    
    let verify = Verify()
    
    @discardableResult
    func addNewProfile() -> CreateProfileRobot {
        return addNew()
    }
    
    func deleteProfile(_ name: String, _ countryname: String) -> ProfileRobot {
        return delete(name, countryname)
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
    
    class Verify: CoreElements {
        
        func profileIsDeleted(_ name: String, _ countryname: String) {
            button("Delete " + countryname + "    Fastest, " + name).checkDoesNotExist()
        }
        
        @discardableResult
        func createdProfile() -> ProfileRobot {
            staticText(successMessage).checkExists()
            return ProfileRobot()
        }
    }
}

