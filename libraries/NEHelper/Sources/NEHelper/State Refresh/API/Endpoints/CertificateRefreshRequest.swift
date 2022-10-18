//
//  CertificateRefreshRequest.swift
//  WireGuardiOS Extension
//
//  Created by Jaroslav on 2021-06-30.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import VPNShared

// Important! If changing this request, don't forget there is `CertificateRequest` class that does the same request, but in vpncore.

struct CertificateRefreshRequest: APIRequest {
    let endpointUrl = "vpn/v1/certificate"
    let httpMethod = "POST"
    let hasBody = true

    let params: Params

    struct Params: Codable {
        let clientPublicKey: String
        let clientPublicKeyMode: String
        let deviceName: String
        let mode: String
        let duration: String?
        let features: VPNConnectionFeatures?

        static func withPublicKey(_ publicKey: String, deviceName: String?, features: VPNConnectionFeatures?) -> Self {
            Self(clientPublicKey: publicKey,
                 clientPublicKeyMode: "EC",
                 deviceName: deviceName ?? "",
                 mode: "session",
                 duration: CertificateConstants.certificateDuration,
                 features: features)
        }
    }

    public typealias Response = VpnCertificate

    init(params: Params) {
        self.params = params
    }
}
