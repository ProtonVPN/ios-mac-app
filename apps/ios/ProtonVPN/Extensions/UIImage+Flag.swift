//
//  Created on 26.01.2022.
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
import UIKit
import ProtonCore_UIFoundations

extension UIImage {
    static func flag(countryCode: String) -> UIImage? {
        // Core uses GB instead of UK for The United Kingdom
        let countryCode = countryCode == "UK" ? "GB" : countryCode

        // normaly we would use IconProvider.flag(forCountryCode: countryCode) but it crashes with country codes that do not have a valid icon
        guard let url = Bundle(for: PMUIFoundations.self).resourceURL?.appendingPathComponent("Resources-UIFoundations.bundle"), let bundle = Bundle(url: url) else {
            return nil
        }

        return UIImage(named: "flags-\(countryCode.uppercased())", in: bundle, compatibleWith: nil)
    }
}
