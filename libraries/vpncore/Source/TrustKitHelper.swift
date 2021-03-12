//
//  TrustKitWrapper.swift
//  ProtonVPN - Created on 21/10/2019.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import TrustKit
import Alamofire

public protocol TrustKitHelperFactory {
    func makeTrustKitHelper() -> TrustKitHelper?
}

public final class TrustKitHelper: SessionDelegate {
    
    typealias Configuration = [String: Any]

    // swiftlint:disable function_body_length
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
                ],
                ".compute.amazonaws.com": [ // <- cert pinning for alternative routes, needs to be addeed to `NSExceptionDomains` in `Info.plist`
                    kTSKEnforcePinning: true,
                    kTSKIncludeSubdomains: true,
                    kForceSubdomains: true,
                    kTSKDisableDefaultReportUri: true,
                    kTSKReportUris: [
                        "https://api.protonvpn.ch/reports/tls"
                    ],
                    kTSKPublicKeyHashes: [
                        "EU6TS9MO0L/GsDHvVc9D5fChYLNy5JdGYpJw0ccgetM=",
                        "iKPIHPnDNqdkvOnTClQ8zQAIKG0XavaPkcEo0LBAABA=",
                        "MSlVrBCdL0hKyczvgYVSRNm88RicyY04Q2y5qrBt0xA=",
                        "C2UxW0T1Ckl9s+8cXfjXxlEqwAfPM4HiW2y3UdtBeCw="
                    ]
                ]
            ]
        ]
                
        #if os(macOS)
            config[kTSKIgnorePinningForUserDefinedTrustAnchors] = false
        #endif
        
        return config
    }
    // swiftlint:enable function_body_length
    
    public typealias Factory = AlamofireWrapperFactory
    private var factory: Factory
    private lazy var alamofireWrapper: AlamofireWrapper = factory.makeAlamofireWrapper()
    private var trustKit: TrustKit!
    
    public init(factory: Factory, hardfail: Bool = true) {
        self.factory = factory
        trustKit = TrustKit(configuration: TrustKitHelper.configuration(hardfail: hardfail))
        super.init()
    }
        
    // MARK: - SessionDelegate
    
    override public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let wrappedCompletionHandler: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void = { [self, task] disposition, credential in
            if disposition == .cancelAuthenticationChallenge, let request = task.originalRequest {
                self.alamofireWrapper.markAsFailedTLS(request: request)
            }
            completionHandler(disposition, credential)
        }
        
        if self.trustKit.pinningValidator.handle(challenge, completionHandler: wrappedCompletionHandler) == false {
            // TrustKit did not handle this challenge: perhaps it was not for server trust
            // or the domain was not pinned. Fall back to the default behavior
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
