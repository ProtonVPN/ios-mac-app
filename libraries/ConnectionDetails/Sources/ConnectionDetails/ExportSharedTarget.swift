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

import ConnectionDetailsShared

public typealias ConnectionScreenFeature = ConnectionDetailsShared.ConnectionScreenFeature

#if canImport(ConnectionDetails_macOS)
import ConnectionDetails_macOS

#endif

#if canImport(ConnectionDetails_iOS)
import ConnectionDetails_iOS

public typealias ConnectionScreenView = ConnectionDetails_iOS.ConnectionScreenView

#endif

