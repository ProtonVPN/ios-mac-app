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

import HomeShared

public typealias ImageAsset = HomeShared.ImageAsset
public typealias HomeAsset = HomeShared.HomeAsset
@available(iOS 17, *)
public typealias HomeFeature = HomeShared.HomeFeature

#if canImport(Home_iOS)
import Home_iOS

@available(iOS 17, *)
public typealias HomeView = Home_iOS.HomeView

#endif

