//
//  Created on 11/02/2022.
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

import SwiftUI

public struct ModalModel {
    public struct Subtitle {
        public let text: String
        public let boldText: [String]

        public init(text: String, boldText: [String] = []) {
            self.text = text
            self.boldText = boldText
        }
    }

    public let title: String
    public let subtitle: Subtitle?
    public let features: [Feature]
    public let primaryButtonTitle: String
    public let secondaryButtonTitle: String?
    public let shouldAddGradient: Bool
}
