//
//  Created on 2026-02-05.
//
//  Copyright (c) 2025 Proton AG
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

#if canImport(SharedViews_macOS)

    import SharedViews_macOS

    public typealias GhostButtonStyle = SharedViews_macOS.GhostButtonStyle
    public typealias ExplicitlySizedHostingController = SharedViews_macOS.ExplicitlySizedHostingController
    public typealias ExplicitlySizedView = SharedViews_macOS.ExplicitlySizedView
    public typealias SwitchButtonDelegate = SharedViews_macOS.SwitchButtonDelegate
    public typealias ButtonState = SharedViews_macOS.ButtonState
    open class HoverDetectionButton: SharedViews_macOS.HoverDetectionButton {}
    public class SwitchButton: SharedViews_macOS.SwitchButton {}
    public class TransparentBackedScroller: SharedViews_macOS.TransparentBackedScroller {}

    public extension ButtonStyle where Self == GhostButtonStyle {
        static var ghost: GhostButtonStyle {
            GhostButtonStyle()
        }
    }

#endif
