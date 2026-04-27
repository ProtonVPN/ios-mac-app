//
//  Created on 21/04/2026.
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

#if os(iOS) && DEBUG
    import os.log

    final class ProTUNAdapterEventDelegate: Sendable {}

    extension ProTUNAdapterEventDelegate: EventCallback {
        func onEvent(event: Event) {
            Logger.adapter.info("Received internal event: \(event, privacy: .public)")
        }
    }

    extension Event: CustomStringConvertible {
        public var description: String {
            switch self {
            case let .connectionStats(rx, tx, idle, el, rtt):
                ".connectionStats(rx:\(rx), tx:\(tx), idle:\(idle), eloss:\(el), rtt:\(rtt))"
            case let .packetCaptureStarted(info):
                String(describing: info)
            case let .packetCaptureStopped(reason):
                String(describing: reason)
            }
        }
    }
#endif
