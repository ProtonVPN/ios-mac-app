//
//  macOSNetworkingDelegate.swift
//  ProtonVPN-mac
//
//  Created by Igor Kulman on 24.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import vpncore
import ProtonCore_Networking
import ProtonCore_Services

// swiftlint:disable type_name
final class macOSNetworkingDelegate: NetworkingDelegate {
    private let alertService: CoreAlertService

    init(alertService: CoreAlertService) {
        self.alertService = alertService
    }

    func set(apiService: APIService) {}
}
// swiftlint:enable type_name

extension macOSNetworkingDelegate {
    func onHumanVerify(methods: [VerifyMethod], startToken: String?, completion: @escaping ((HumanVerifyHeader, HumanVerifyIsClosed, SendVerificationCodeBlock?) -> Void)) {
        // there is no human verification on macOS so just show en error
        alertService.push(alert: UserVerificationAlert(verificationMethods: VerificationMethods(availableTokenTypes: methods.compactMap({ HumanVerificationToken.TokenType(rawValue: $0.rawValue) }), captchaToken: startToken), error: NSError(code: 0, localizedDescription: LocalizedString.errorUserFailedHumanValidation), success: { _ in }, failure: { _ in }))

        // report human verification as closed by the user
        // should result in the request failing with error
        completion([:], true, nil)
    }

    func getSupportURL() -> URL {
        return URL(string: CoreAppConstants.ProtonVpnLinks.support)!
    }
}

extension macOSNetworkingDelegate {
    func onForceUpgrade(message: String) {
        PMLog.ET("Unexpected force upgrade on macOS")
    }
}
