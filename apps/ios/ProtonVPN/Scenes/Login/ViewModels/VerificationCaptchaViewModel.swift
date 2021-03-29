//
//  VerificationCaptchaViewModel.swift
//  ProtonVPN - Created on 24/10/2019.
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

protocol VerificationCaptchaViewModelFactory {
    func makeVerificationCaptchaViewModel(token: String) -> VerificationCaptchaViewModel
}

extension DependencyContainer: VerificationCaptchaViewModelFactory {
    func makeVerificationCaptchaViewModel(token: String) -> VerificationCaptchaViewModel {
        return VerificationCaptchaViewModel(factory: self, token: token)
    }
}

final class VerificationCaptchaViewModel {
    
    // Callbacks for coordinator
    var tokenReceived: ((HumanVerificationToken) -> Void)?
    
    // Factory
    typealias Factory = ChallengeFactory

    private let factory: Factory
    private lazy var challenge: Challenge = factory.makeChallenge()
    
    let captchaToken: String
    
    init(factory: Factory, token: String) {
        self.factory = factory
        self.captchaToken = token
    }

    func captchaLoadingStarted() {
        challenge.userDidStartVerification()
    }
    
    func setCaptchaToken(_ token: String) {
        challenge.userDidFinishVerification()

        let humanVerificationToken = HumanVerificationToken(type: .captcha, token: token, input: captchaToken)
        tokenReceived?(humanVerificationToken)
    }
    
}
