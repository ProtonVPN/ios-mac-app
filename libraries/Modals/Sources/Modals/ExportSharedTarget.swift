//
//  Created on 2025-03-07.
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

import ModalsShared

public typealias Asset = ModalsShared.Asset
public typealias ImageAsset = ModalsShared.ImageAsset
public typealias ModalType = ModalsShared.ModalType
public typealias UserAccountUpdateViewModel = ModalsShared.UserAccountUpdateViewModel
public typealias DiscourageSecureCoreFeature = ModalsShared.DiscourageSecureCoreFeature

import ModalsServices

public typealias PlanOption = ModalsServices.PlanOption

#if canImport(Modals_macOS)
    import Modals_macOS

    public typealias ModalsFactory = Modals_macOS.ModalsFactory

#endif

#if canImport(Modals_iOS)
    import Modals_iOS

    public typealias ModalsFactory = Modals_iOS.ModalsFactory
    public typealias PlansClient = Modals_iOS.PlansClient
    public typealias TelemetrySettingsViewController = Modals_iOS.TelemetrySettingsViewController
    public typealias WhatsNewView = Modals_iOS.WhatsNewView

#endif
