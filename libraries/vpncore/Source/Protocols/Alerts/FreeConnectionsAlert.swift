//
//  Created on 2023-09-06.
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
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public class FreeConnectionsAlert: SystemAlert {

    #if canImport(UIKit)
    public typealias FreeCountriesArray = [(String, UIImage?)]
    #elseif canImport(AppKit)
    public typealias FreeCountriesArray = [(String, NSImage?)]
    #endif

    public var title: String?
    public var message: String?
    public var actions = [AlertAction]()
    public let isError = false
    public var dismiss: (() -> Void)?
    public var countries = FreeCountriesArray()

    public init(countries: FreeCountriesArray) {
        self.countries = countries
    }

}
