//
//  Created on 23/08/2023.
//
//  Copyright (c) 2023 Proton AG
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
import XCTest
import fusion

protocol Verifier { }

extension CoreElements: Verifier {
    @discardableResult
    func isShowingUpsellModal(ofType type: UpsellModalType) -> Self {
        staticText(type.identifyingString).checkExists()
        return self
    }
}

enum UpsellModalType {
    case profiles
    case secureCore

    var identifyingString: String {
        switch self {
        case .secureCore:
            return "Double the encryption with Secure Core"
        case .profiles:
            return "Get quick access to your frequent connections"
        }
    }
}
