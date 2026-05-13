//
//  Created on 03/06/2024.
//
//  Copyright (c) 2024 Proton AG
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

import ComposableArchitecture
import CoreConnection
import Domain
import Ergonomics
import Foundation
import Strings
import VPNAppCore

// #if canImport(UIKit)
//    import class UIKit.UIApplication
// #elseif canImport(AppKit)
//    import class AppKit.NSApplication
// #endif
//
// let didBecomeActiveNotification: NSNotification.Name = {
//    #if canImport(UIKit)
//        return UIApplication.didBecomeActiveNotification
//    #elseif canImport(AppKit)
//        return NSApplication.didBecomeActiveNotification
//    #else
//        fatalError("Unsupported platform")
//    #endif
// }()
