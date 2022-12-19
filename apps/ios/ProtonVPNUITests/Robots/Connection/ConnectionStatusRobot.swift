//
//  ConnectionStatusRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-08-10.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import pmtest
import XCTest

fileprivate let headerTitle = "Status"
fileprivate let statusNotConnected = "Not Connected"
fileprivate let statusConnected = "Connected to "
fileprivate let saveAsProfileButton = "Save as Profile"
fileprivate let createSuccessMessage = "New Profile saved"
fileprivate let deleteProfileButton = "Delete profile"
fileprivate let deleteSuccessMessage = "Profile has been deleted"
fileprivate let tabQCInactive = "quick connect inactive button"
fileprivate let tabQCActive = "quick connect active button"
fileprivate let netshieldUpgradeButton = "Upgrade"
fileprivate let getPlusButton = "GetPlusButton"
fileprivate let notNowbutton = "UseFreeButton"

class ConnectionStatusRobot: CoreElements {
    
    let verify = Verify()
 
    func saveAsProfile() -> ConnectionStatusRobot {
        button(saveAsProfileButton).tap()
        return ConnectionStatusRobot()
    }

    func deleteProfile() -> ConnectionStatusRobot {
        button(deleteProfileButton).tap()
        return ConnectionStatusRobot()
    }
    
    @discardableResult
    func disconnectFromAServer() -> ConnectionStatusRobot {
        button(tabQCActive).tap()
        return ConnectionStatusRobot()
    }

    class Verify: CoreElements {
        
        @discardableResult
        func savedAsAProfile() -> MainRobot {
            staticText(createSuccessMessage).checkExists()
            button(saveAsProfileButton).checkExists()
            return MainRobot()
        }
        
        @discardableResult
        func profileIsDeleted() -> MainRobot {
            staticText(deleteSuccessMessage).checkExists()
            button(deleteProfileButton).checkExists()
            return MainRobot()
        }
        
        @discardableResult
        func connectedToAServer(_ name: String) -> MainRobot {
            staticText(statusConnected + name).wait(time: 35).checkExists()
            button(tabQCActive).wait().checkExists()
            return MainRobot()
        }
        
        @discardableResult
        func connectedToASCServer(_ name: String) -> ConnectionStatusRobot {
            staticText(statusConnected + name).wait(time: 30).checkExists()
            button(tabQCActive).wait().checkExists()
            return ConnectionStatusRobot()
        }
        
        @discardableResult
        func disconnectedFromAServer() -> MainRobot {
            staticText(statusNotConnected).wait().checkExists()
            button(tabQCInactive).wait().checkExists()
            return MainRobot()
        }
        
        @discardableResult
        func connectedToAProfile() -> MainRobot {
            button(deleteProfileButton).checkExists()
            return MainRobot()
        }
        
        @discardableResult
        func connectionStatusNotConnected() -> CountryListRobot {
            staticText("Not Connected").wait(time: 10).checkExists()
            return CountryListRobot()
        }
        
        @discardableResult
        func connectionStatusConnected<T: CoreElements>(robot _: T.Type) -> T {
            button(tabQCActive).wait(time: 10).checkExists()
            return T()
        }
        
        @discardableResult
        func protocolNameIsCorrect(_ protocolname: String) -> ConnectionStatusRobot {
            staticText(protocolname).wait(time: 30).checkExists()
            return ConnectionStatusRobot()
        }
        
        func upsellModalIsShown() -> ConnectionStatusRobot {
            button(getPlusButton).wait().checkExists()
            button(notNowbutton).tap()
            return ConnectionStatusRobot()
        }
    }
}
