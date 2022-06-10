//
//  CertificateRefreshRequest.swift
//  WireGuardiOS Extension
//
//  Created by Jaroslav on 2021-06-30.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

protocol APIRequest {
    var endpointUrl: String { get }
    var httpMethod: String { get }
    var body: Data? { get }
}

// Important! If changing this request, don't forget there is `CertificateRequest` class that does the same request, but in vpncore.

struct CertificateRefreshRequest: APIRequest {
    let endpointUrl = "vpn/v1/certificate"
    let httpMethod = "POST"

    let params: Params

    struct Params: Codable {
        let clientPublicKey: String
        let clientPublicKeyMode: String
        let deviceName: String
        let mode: String
        let duration: String?
        let features: VPNConnectionFeatures?
    }

    typealias Response = VpnCertificate

    init(params: Params) {
        self.params = params
    }

    var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .custom(capitalizeFirstLetter)
        return encoder
    }

    var body: Data? {
        return try? encoder.encode(params)
    }
}
