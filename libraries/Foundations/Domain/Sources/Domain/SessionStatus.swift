//
//  Created on 26/06/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
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

import Foundation

/// The app's authenticated-session state.
///
/// This is the source of truth behind `@Shared(.sessionStatus)`, which lets UI and services
/// observe whether the user is logged in without depending on `AppSessionManager` directly.
/// `AppSessionManager` remains the sole writer of this value.
public enum SessionStatus: Sendable, Equatable {
    /// The session state has not been determined yet (e.g. before silent log-in completes at launch).
    case undetermined
    /// No authenticated session is established (logged out).
    case notEstablished
    /// An authenticated session is established (logged in).
    case established
}
