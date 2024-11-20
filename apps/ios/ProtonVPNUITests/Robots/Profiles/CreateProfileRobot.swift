//
//  CreateProfileRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-05-18.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import fusion
import UITestsHelpers
import Foundation
import Strings

fileprivate let profileSameName = Localizable.profileNameNeedsToBeUnique
fileprivate let profileNameField = Localizable.enterProfileName
fileprivate let countryField = Localizable.selectCountry
fileprivate let countryButton = Localizable.country
fileprivate let countriesLabel = Localizable.countries
fileprivate let serverField = Localizable.selectServer
fileprivate let saveProfileButton = Localizable.save
fileprivate let secureCoreToggle = Localizable.secureCore
fileprivate let protocolCellId = Localizable.protocol

class CreateProfileRobot: CoreElements {

    let verify = Verify()

    @discardableResult
    func setProfileDetails(profile: String, country: String, server: String? = nil, secureCoreState: Bool = false) -> CreateProfileRobot {
        return enterProfileName(profile)
            .setSecureCoreToggle(state: secureCoreState)
            .chooseCountry(country)
            .chooseServer(server)
            .chooseProtocol()
    }

    @discardableResult
    func saveProfile<T: CoreElements>(robot _: T.Type) -> T {
        button(saveProfileButton).tap()
        return T()
    }

    @discardableResult
    private func enterProfileName(_ name: String) -> CreateProfileRobot {
        textField(profileNameField).waitUntilExists(time: WaitTimeout.short)
            .clearText()
            .typeText(name)
            .typeText("\n")
        return self
    }

    @discardableResult
    private func tapCountryField() -> CreateProfileRobot {
        let countryField = staticText(countryField)
        if countryField.waitUntilExists(time: WaitTimeout.short).exists() {
            countryField.tap()
        } else {
            staticText(NSPredicate(format: "label CONTAINS[c] %@", "Country")).waitUntilExists(time: WaitTimeout.short).tap()
        }

        return self
    }

    @discardableResult
    private func chooseCountry(_ countryname: String) -> CreateProfileRobot {
        tapCountryField()
        staticText(countriesLabel).waitUntilExists().checkExists()
        staticText()
            .containsLabel(countryname)
            .checkExists(message: "Country \(countryname) not found")
            .tap()
        return self
    }

    @discardableResult
    private func tapServerField() -> CreateProfileRobot {
        staticText(serverField)
            .waitUntilExists(time: WaitTimeout.short)
            .tap()
        return self
    }

    @discardableResult
    private func chooseServer(_ serverName: String?) -> CreateProfileRobot {
        tapServerField()
        staticText(Localizable.server).checkExists()
        if let serverName = serverName {
            staticText()
                .containsLabel(serverName)
                .checkExists(message: "Server \(serverName) not found").tap()
        } else {
            cell().byIndex(0).waitUntilExists(time: WaitTimeout.short).tap()
        }

        return self
    }

    @discardableResult
    private func setSecureCoreToggle(state: Bool) -> CreateProfileRobot {
        swittch(secureCoreToggle)
            .waitUntilExists(time: WaitTimeout.short).checkExists()
        let secureCoreValue = swittch(secureCoreToggle).value() as? String
        let currentSecureCoreState = Bool(secureCoreValue ?? "") ?? false

        if state != currentSecureCoreState {
            swittch(secureCoreToggle).tap()
        }

        return self
    }

    @discardableResult
    private func chooseProtocol(_ connectionProtocol: ConnectionProtocol = ConnectionProtocol.WireGuardUDP) -> CreateProfileRobot {
        let protocolCell = cell(protocolCellId).byIndex(1).tap()
        staticText(connectionProtocol.rawValue).tap()
        protocolCell.checkExists()
        return self
    }

    class Verify: CoreElements {

        @discardableResult
        func profileWithSameName() -> CreateProfileRobot {
            staticText(profileSameName).checkExists()
            return CreateProfileRobot()
        }

        @discardableResult
        func isOnProfilesEditScreen() -> CreateProfileRobot {
            staticText("Create Profile").checkExists(message: "Profile edit screen is not visible")
            return CreateProfileRobot()
        }
    }
}
