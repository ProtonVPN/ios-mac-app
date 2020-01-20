//
//  TrustKitWrapper.swift
//  ProtonVPN - Created on 21/10/2019.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import TrustKit

public protocol TrustKitHelperFactory {
    func makeTrustKitHelper() -> TrustKitHelper?
}

public final class TrustKitHelper {
    
    typealias Configuration = [String: Any]
    
    private static func configuration(hardfail: Bool = true) -> Configuration {
        var config: Configuration = [
            kTSKSwizzleNetworkDelegates: false,
            kTSKPinnedDomains: [
                "protonvpn.com": [
                    kTSKEnforcePinning: hardfail,
                    kTSKIncludeSubdomains: true,
                    kTSKDisableDefaultReportUri: true,
                    kTSKReportUris: [
                        "https://api.protonvpn.ch/reports/tls"
                    ],
                    kTSKPublicKeyHashes: [
                        "+0dMG0qG2Ga+dNE8uktwMm7dv6RFEXwBoBjQ43GqsQ0=",
                        "8joiNBdqaYiQpKskgtkJsqRxF7zN0C0aqfi8DacknnI=",
                        "JMI8yrbc6jB1FYGyyWRLFTmDNgIszrNEMGlgy972e7w=",
                        "Iu44zU84EOCZ9vx/vz67/MRVrxF1IO4i4NIa8ETwiIY="
                    ]
                ],
                "protonvpn.ch": [
                    kTSKEnforcePinning: hardfail,
                    kTSKIncludeSubdomains: true,
                    kTSKDisableDefaultReportUri: true,
                    kTSKReportUris: [
                        "https://api.protonvpn.ch/reports/tls"
                    ],
                    kTSKPublicKeyHashes: [
                        "IEwk65VSaxv3s1/88vF/rM8PauJoIun3rzVCX5mLS3M=",
                        "drtmcR2kFkM8qJClsuWgUzxgBkePfRCkRpqUesyDmeE=",
                        "YRGlaY0jyJ4Jw2/4M8FIftwbDIQfh8Sdro96CeEel54=",
                        "AfMENBVvOS8MnISprtvyPsjKlPooqh8nMB/pvCrpJpw="
                    ]
                ]
            ]
        ]
                
        #if os(macOS)
            config[kTSKIgnorePinningForUserDefinedTrustAnchors] = false
        #endif
        
        return config
    }
    
    public typealias Factory = CoreAlertServiceFactory
    private var factory: Factory
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private var trustKit: TrustKit!
    
    public init(factory: Factory, hardfail: Bool = true) {
        self.factory = factory
        trustKit = TrustKit(configuration: TrustKitHelper.configuration(hardfail: hardfail))
        
        trustKit.pinningValidatorCallback = { result, notedHostname, policy in
            if result.evaluationResult != .success, result.finalTrustDecision != .shouldAllowConnection {
                self.validationFailure()
            }
        }
        
    }
    
    private func validationFailure() {
        alertService.push(alert: MITMAlert())
    }
    
    public var authenticationChallengeTask: ((URLSession, URLSessionTask, URLAuthenticationChallenge, @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Void)? {
        return { session, task, challenge, completionHandler in
            if self.trustKit.pinningValidator.handle(challenge, completionHandler: completionHandler) == false {
                // TrustKit did not handle this challenge: perhaps it was not for server trust
                // or the domain was not pinned. Fall back to the default behavior
                completionHandler(.performDefaultHandling, nil)
            }
        }
    }
    
}
