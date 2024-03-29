//
//  Created on 21/09/2022.
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

public struct FullScreenImage: Codable {
    public let source: [Source]
    public let alternativeText: String

    public var firstURL: URL? {
        guard let urlString = source.first?.url else {
            return nil
        }
        return URL(string: urlString)
    }

    public struct Source: Codable {
        public let url: String
        public let type: String
        public let width: CGFloat?
        public let height: CGFloat?

        enum CodingKeys: String, CodingKey { // swiftlint:disable:this nesting
            case type
            case width
            case height
            case url = "URL"
        }
    }
}
