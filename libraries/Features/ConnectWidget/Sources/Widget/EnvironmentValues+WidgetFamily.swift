//
//  Created on 2025-04-09 by Pawel Jurczyk.
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

#if FALSE

    import SwiftUI
    import WidgetKit

    /// This extension messes up with the actual value of the `widgetFamily`, resulting in always using the `defaultValue`.
    /// Only remove the compiler flag temporarily for testing purposes and never commit it to develop.
    /// This extension helps to create Previews of the widget in the correct size without providing the actual timelines.
    public extension PreviewTrait where T == Preview.ViewTraits {
        enum WidgetSize {
            case small
            case medium
            case large
        }

        @MainActor
        static func widgetLayout(size: WidgetSize) -> PreviewTrait<T> {
            switch size {
            case .small:
                .fixedLayout(width: 158, height: 158)
            case .medium:
                .fixedLayout(width: 338, height: 158)
            case .large:
                .fixedLayout(width: 338, height: 354)
            }
        }
    }

    extension WidgetFamily: @retroactive EnvironmentKey {
        public static var defaultValue: WidgetFamily = .systemMedium
    }

    public extension EnvironmentValues {
        var widgetFamily: WidgetFamily {
            get { self[WidgetFamily.self] }
            set { self[WidgetFamily.self] = newValue }
        }
    }

#endif
