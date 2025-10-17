//
//  Created on 18.02.2022.
//
//  Copyright (c) 2022 Proton AG
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

#if DEBUG
    import Foundation

    import Domain
    import VPNShared

    public final class NATTypePropertyProviderMock: NATTypePropertyProvider {
        public var natType: NATType = .default {
            didSet {
                AppEvent.natType.post(natType)
            }
        }

        public func adjustAfterPlanChange(from _: Int, to tier: Int) {
            if tier.isFreeTier {
                natType = .default
            }
        }

        public init() {}
    }
#endif
