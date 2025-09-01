//
//  Created on 01/09/2025 by Shahin Katebi.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

#if os(macOS)

    import Dependencies
    import Foundation

    public enum SystemExtensionManagerKey: DependencyKey {
        public static let liveValue: SystemExtensionManager = {
            // Get from the shared dependency container
            guard let container = Container.sharedContainer as? SystemExtensionManagerFactory else {
                fatalError("Container must implement SystemExtensionManagerFactory")
            }
            return container.makeSystemExtensionManager()
        }()
    }

    public extension DependencyValues {
        var systemExtensionManager: SystemExtensionManager {
            get { self[SystemExtensionManagerKey.self] }
            set { self[SystemExtensionManagerKey.self] = newValue }
        }
    }

#endif
