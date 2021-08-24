//
//  iOSNetworkingDelegate.swift
//  ProtonVPN
//
//  Created by Igor Kulman on 24.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import vpncore
import Crypto
import ProtonCore_Networking
import ProtonCore_Services
import ProtonCore_ForceUpgrade
import ProtonCore_HumanVerification

final class iOSNetworkingDelegate: NetworkingDelegate {
    private let forceUpgradeService: ForceUpgradeDelegate
    private var humanVerify: HumanVerifyDelegate?

    init() {
        forceUpgradeService = ForceUpgradeHelper(config: .mobile(URL(string: URLConstants.appStoreUrl)!))
    }

    func set(apiService: APIService) {
        humanVerify = HumanCheckHelper(apiService: apiService, supportURL: getSupportURL())
    }
}

extension iOSNetworkingDelegate {
    func onHumanVerify(methods: [VerifyMethod], startToken: String?, completion: @escaping ((HumanVerifyHeader, HumanVerifyIsClosed, SendVerificationCodeBlock?) -> Void)) {
        humanVerify?.onHumanVerify(methods: methods, startToken: startToken, completion: completion)
    }

    func getSupportURL() -> URL {
        return URL(string: CoreAppConstants.ProtonVpnLinks.support)!
    }
}

extension iOSNetworkingDelegate {
    func onForceUpgrade(message: String) {
        forceUpgradeService.onForceUpgrade(message: message)
    }
}

extension iOSNetworkingDelegate {
    public func getToken(bySessionUID uid: String) -> AuthCredential? {
        guard let credentials = AuthKeychain.fetch() else {
            return nil
        }
        return ProtonCore_Networking.AuthCredential(sessionID: credentials.sessionId, accessToken: credentials.accessToken, refreshToken: credentials.refreshToken, expiration: credentials.expiration, privateKey: nil, passwordKeySalt: nil)
    }

    public func onLogout(sessionUID uid: String) {

    }

    public func onUpdate(auth: Credential) {
        guard let credentials = AuthKeychain.fetch() else {
            return
        }

        try? AuthKeychain.store(credentials.updatedWithAuth(auth: auth))
    }

    public func onRefresh(bySessionUID uid: String, complete: @escaping AuthRefreshComplete) {
        PMLog.D("Implement me")
    }

    public func onForceUpgrade() {

    }
}

extension iOSNetworkingDelegate {
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
        CryptoUpdateTime(serverTime)
    }
    func isReachable() -> Bool {
        return true
    }
    func onDohTroubleshot() { }
}
