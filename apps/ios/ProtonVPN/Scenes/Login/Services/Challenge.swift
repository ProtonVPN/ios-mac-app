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

import Alamofire
import Foundation
import vpncore
import ProtonCore_Challenge
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

    func appendCheckedUsername(_ username: String)

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

    func appendCheckedUsername(_ username: String) {
        challenge.appendCheckedUsername(username)
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

/**
 Modifies every request that contains challenge data with the latest challenge data.

 A request with challenge data might trigger human verification. When the user completes human verification the request is automatically retried. The problem is that human verification affects the challenge data in that retried request. As a result it cannot be just retried, it needs to be modified with the latest challenge data before retrying.
 */
final class ChallengeAppSpecificRequestAdapter: RequestAdapter {
    private let challenge: Challenge

    init(challenge: Challenge) {
        self.challenge = challenge
    }

    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        guard let data = urlRequest.httpBody, let jsonData = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], var json = jsonData, var payload = json["Payload"] as? [String: Any] else {
            completion(.success(urlRequest))
            return
        }

        PMLog.D("Modifying request with latest challenge data")

        var urlRequest = urlRequest
        payload["vpn-ios-challenge"] = try? challenge.export()
        json["Payload"] = payload
        urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: json, options: [])

        completion(.success(urlRequest))
    }
}
