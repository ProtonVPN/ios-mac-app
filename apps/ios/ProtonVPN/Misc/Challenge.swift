//
//  Challenge.swift
//  ProtonVPN - Created on 17.02.2021.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
import vpncore
import PMChallenge
import UIKit

protocol ChallengeFactory {
    func makeChallenge() -> Challenge
}

enum ChallengeTextFieldType {
    case username
    case password
    case passwordConfirmation
    case recoveryEmail
    case verificationCode
}

protocol Challenge {
    func start()

    func userDidStartVerification()
    func userDidFinishVerification()

    func observeTextField(textField: UITextField, type: ChallengeTextFieldType)

    func export() throws -> [String: Any]
}

final class CoreChallenge: Challenge {
    let challenge = PMChallenge()

    func start() {
        challenge.reset()
    }

    func userDidStartVerification() {
        challenge.requestVerify()
    }

    func userDidFinishVerification() {
        do {
            try challenge.verificationFinish()
        } catch {
            PMLog.ET("Finishing challenge verification failed: \(error.localizedDescription)")
        }
    }

    func observeTextField(textField: UITextField, type: ChallengeTextFieldType) {
        do {
            let textFieldType: PMChallenge.TextFieldType
            switch type {
            case .username:
                textFieldType = .username
            case .password:
                textFieldType = .password
            case .recoveryEmail:
                textFieldType = .recovery
            case .verificationCode:
                textFieldType = .verification
            case .passwordConfirmation:
                textFieldType = .confirm
            }
            try challenge.observeTextField(textField, type: textFieldType)
        } catch {
            PMLog.ET("Observing text for challenge field failed: \(error.localizedDescription)")
        }
    }

    func export() throws -> [String: Any] {
        let data = challenge.export()
        return try data.asDictionary()
    }
}
