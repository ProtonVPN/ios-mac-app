//
//  Created on 10/11/2022.
//
//  Copyright (c) 2022 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

public struct VPNPartnersResponse: Codable {
    public let code: Int
    public let partnerTypes: [PartnerType]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.code = try container.decode(Int.self, forKey: .code)
        self.partnerTypes = try container.decode([PartnerType].self, forKey: .partnerTypes)
    }

    public init(code: Int, partnerTypes: [PartnerType]) {
        self.code = code
        self.partnerTypes = partnerTypes
    }
}

public struct PartnerType: Codable {
    public let type: String /// It's the `name` of the partner type for our purposes
    public let description: String
    public let iconURL: URL?
    public let partners: [Partner]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.description = try container.decode(String.self, forKey: .description)
        let iconString = try? container.decode(String.self, forKey: .iconURL)
        self.iconURL = URL(string: iconString ?? "")
        self.partners = try container.decode([Partner].self, forKey: .partners)
    }

    public init(type: String, description: String, iconURL: URL?, partners: [Partner]) {
        self.type = type
        self.description = description
        self.iconURL = iconURL
        self.partners = partners
    }
}

extension Array: DefaultableProperty where Element == PartnerType {
}
