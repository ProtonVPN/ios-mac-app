//
//  Created on 10/08/2026.
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

import Domain
import Foundation

/// What ProTUN is doing with the packet capture the app declared in the provider configuration.
public enum PacketCaptureReport: Equatable, Sendable {
    case stopped(PacketCaptureInterruptionReason)
    /// The tunnel is still coming up but has not yet started the capture. The extension doesn't report the capture as
    /// recording until ProTUN has reported that it's successfully connected.
    case starting
    case recording(since: Date)

    /// All-zeroes, likely written by `zeroAll()`, indicates the tunnel has gone away.
    public static let cleared: Self = .stopped(.connectionTerminated)
}
