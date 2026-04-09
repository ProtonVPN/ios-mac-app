//
//  LocalAgent+Certs.swift
//  vpncore - Created on 27.04.2021.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
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
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation

extension LocalAgentImplementation {
    var rootCerts: String {
        """
        -----BEGIN CERTIFICATE-----
        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
        -----END CERTIFICATE-----
        -----BEGIN CERTIFICATE-----
        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
        EA==
        -----END CERTIFICATE-----
        """
    }
}
