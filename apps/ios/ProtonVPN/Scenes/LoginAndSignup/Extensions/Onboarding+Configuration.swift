//
//  Created on 05.01.2022.
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

import Foundation
import Onboarding
import vpncore

extension Configuration {
    init(showFirstConnection: Bool) {
        self.init(variant: showFirstConnection ? OnboardingVariant.A : OnboardingVariant.B, colors: Colors(background: .backgroundColor(), text: .normalTextColor(), textAccent: .textAccent(), brand: .brandColor(), weakText: .weakTextColor(), activeBrandButton: .brandLighten20Color(), secondaryBackground: .secondaryBackgroundColor(), textInverted: .backgroundColor(), notification: .normalTextColor(), weakInteraction: .weakInteractionColor()), constants: Constants(numberOfDevices: AccountPlan.plus.devicesCount, numberOfServers: AccountPlan.plus.serversCount, numberOfFreeServers: AccountPlan.free.serversCount, numberOfFreeCountries: AccountPlan.free.countriesCount, numberOfCountries: AccountPlan.plus.countriesCount))
    }
}
