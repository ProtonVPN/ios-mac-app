//
//  Created on 11/04/2024.
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

#if os(macOS)
    import Ergonomics
    import Foundation

    /// Collection of utilities to retrieve various informations about app startup.
    public extension AppStartup {
        private(set) static var isLaunchedAtLogin: Bool = false

        /// Call this as soon as possible when app is launched in order set ``isLaunchedAtLogin``.
        static func processStartAppleEvent() {
            isLaunchedAtLogin = NSAppleEventManager.shared().currentAppleEvent?.isOpenAppLoginItemLaunchEvent == true
            log.info("App is launched at login: \(isLaunchedAtLogin)", category: .app)
        }
    }

    extension NSAppleEventDescriptor {
        var isOpenEvent: Bool {
            eventClass == kCoreEventClass && eventID == kAEOpenApplication
        }

        var isOpenAppLoginItemLaunchEvent: Bool {
            guard isOpenEvent else { return false }
            return paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        }
    }
#endif
