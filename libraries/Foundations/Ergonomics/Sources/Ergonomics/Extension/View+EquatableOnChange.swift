//
//  Created on 03/06/2025 by adam.
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

#if canImport(SwiftUI)
    import SwiftUI

    public extension View {
        @available(macOS 14.0, iOS 17.0, tvOS 17.0, *)
        func onChange<V>(
            of value: V,
            to checkValue: V,
            _ action: @escaping (_ oldValue: V, _ newValue: V) -> Void
        ) -> some View where V: Equatable {
            onChange(of: value) { oldValue, newValue in
                if newValue == checkValue {
                    action(oldValue, newValue)
                }
            }
        }

        func onChange<V>(
            of value: V,
            to checkValue: V,
            _ action: @escaping (_ newValue: V) -> Void
        ) -> some View where V: Equatable {
            onChange(of: value) { newValue in
                if newValue == checkValue {
                    action(newValue)
                }
            }
        }
    }
#endif
