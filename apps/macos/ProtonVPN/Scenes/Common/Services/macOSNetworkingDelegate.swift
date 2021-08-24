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
        #warning("Get Core help to implement this properly")
        alertService.push(alert: UserVerificationAlert(verificationMethods: VerificationMethods(availableTokenTypes: methods.compactMap({ HumanVerificationToken.TokenType(rawValue: $0.rawValue) }), captchaToken: startToken), error: NSError(), success: { token in
            PMLog.ET("No idea how to handle")
        }, failure: { error in
            PMLog.ET("No idea how to handle")
        }))
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

extension macOSNetworkingDelegate {
    var locale: String {
        return NSLocale.current.languageCode ?? "en_US"
    }
    var appVersion: String {
        return ApiConstants.appVersion
    }
    var userAgent: String? {
        return ApiConstants.userAgent
    }
    func onUpdate(serverTime: Int64) {
        PMLog.ET("macOS does not support CryptoUpdateTime")
    }
    func isReachable() -> Bool {
        return true
    }
    func onDohTroubleshot() { }
}
