//
//  VPNStreamingResponse.swift
//  vpncore - Created on 19.04.21.
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
import VPNShared

public typealias StreamingDictServices = [String: [String: [VpnStreamingOption]]]

extension StreamingDictServices: DefaultableProperty { }

public struct VPNStreamingResponse: Codable {
    public let code: Int
    public let resourceBaseURL: String
    public let streamingServices: StreamingDictServices

    init(code: Int, resourceBaseURL: String, streamingServices: StreamingDictServices) {
        self.code = code
        self.resourceBaseURL = resourceBaseURL
        self.streamingServices = streamingServices
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(Int.self, forKey: .code)
        resourceBaseURL = try container.decode(String.self, forKey: .resourceBaseURL)
        streamingServices = try container.decode(StreamingDictServices.self, forKey: .streamingServices)
            .flattened(removing: "*")
    }
}
