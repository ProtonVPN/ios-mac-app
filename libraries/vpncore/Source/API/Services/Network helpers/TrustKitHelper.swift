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

    // swiftlint:disable function_body_length
    private static func configuration(hardfail: Bool = true) -> Configuration {
        
        let subdomainHashes = [
            "drtmcR2kFkM8qJClsuWgUzxgBkePfRCkRpqUesyDmeE=",
            "YRGlaY0jyJ4Jw2/4M8FIftwbDIQfh8Sdro96CeEel54=",
            "AfMENBVvOS8MnISprtvyPsjKlPooqh8nMB/pvCrpJpw="
        ]
        
        var config: Configuration = [
            kTSKSwizzleNetworkDelegates: false,
            kTSKPinnedDomains: [
                "verify.protonmail.com": [
                    kTSKEnforcePinning: hardfail,
                    kTSKIncludeSubdomains: true,
                    kTSKDisableDefaultReportUri: true,
                    kTSKReportUris: [
                        "https://api.protonvpn.ch/reports/tls"
                    ],
                    kTSKPublicKeyHashes: subdomainHashes
                ],
                "verify.protonvpn.com": [
                    kTSKEnforcePinning: hardfail,
                    kTSKIncludeSubdomains: true,
                    kTSKDisableDefaultReportUri: true,
                    kTSKReportUris: [
                        "https://api.protonvpn.ch/reports/tls"
                    ],
                    kTSKPublicKeyHashes: subdomainHashes
                ],
                "account.protonmail.com": [
                    kTSKEnforcePinning: hardfail,
                    kTSKIncludeSubdomains: true,
                    kTSKDisableDefaultReportUri: true,
                    kTSKReportUris: [
                        "https://api.protonvpn.ch/reports/tls"
                    ],
                    kTSKPublicKeyHashes: subdomainHashes
                ],
                "protonvpn.com": [
                    kTSKEnforcePinning: hardfail,
                    kTSKIncludeSubdomains: true,
                    kTSKDisableDefaultReportUri: true,
                    kTSKReportUris: [
                        "https://api.protonvpn.ch/reports/tls"
                    ],
                    kTSKPublicKeyHashes: [
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
                    kTSKPublicKeyHashes: subdomainHashes
                ],
                "proton.me": [
                    kTSKEnforcePinning: hardfail,
                    kTSKIncludeSubdomains: true,
                    kTSKDisableDefaultReportUri: true,
                    kTSKReportUris: [
                        "https://api.protonvpn.ch/reports/tls"
                    ],
                    kTSKPublicKeyHashes: [
                        "CT56BhOTmj5ZIPgb/xD5mH8rY3BLo/MlhP7oPyJUEDo=",
                        "35Dx28/uzN3LeltkCBQ8RHK0tlNSa2kCpCRGNp34Gxc=",
                        "qYIukVc63DEITct8sFT7ebIq5qsWmuscaIKeJx+5J5A="
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

    public let trustKit: TrustKit!
    
    public init(hardfail: Bool = true) {
        trustKit = TrustKit(configuration: TrustKitHelper.configuration(hardfail: hardfail))
    }
}
