//
//  VpnCertificate.swift
//  vpncore - Created on 15.04.2021.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation

public struct VpnCertificate: Codable {
    public let certificate: String
    public let validUntil: Date
    public let refreshTime: Date

    public var isExpired: Bool {
        return Date() > validUntil
    }

    public var shouldBeRefreshed: Bool {
        return Date() > refreshTime
    }

    enum CodingKeys: String, CodingKey {
        case certificate = "Certificate"
        case validUntil = "ExpirationTime"
        case refreshTime = "RefreshTime"
    }
}

public extension VpnCertificate {
    init(dict: JSONDictionary) throws {
        certificate = try dict.stringOrThrow(key: "Certificate")
        validUntil = try dict.unixTimestampOrThrow(key: "ExpirationTime")
        refreshTime = try dict.unixTimestampOrThrow(key: "RefreshTime")
    }
}

public struct VpnCertificateWithFeatures {
    public let certificate: VpnCertificate
    public let features: VPNConnectionFeatures?

    public init(certificate: VpnCertificate, features: VPNConnectionFeatures?) {
        self.certificate = certificate
        self.features = features
    }
}
