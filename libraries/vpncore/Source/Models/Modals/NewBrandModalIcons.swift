//
//  Created on 21/04/2022.
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
import Modals
import ProtonCore_UIFoundations

public struct NewBrandModalIcons: NewBrandIcons {
    public let vpnMain: Image
    public let driveMain: Image
    public let calendarMain: Image
    public let mailMain: Image

    public init() {
        #if os(macOS)
        vpnMain = Bundle.vpnCore.image(forResource: Image.Name("VPN app logo"))!
        driveMain = Bundle.vpnCore.image(forResource: Image.Name("Drive app logo"))!
        calendarMain = Bundle.vpnCore.image(forResource: Image.Name("Calendar app logo"))!
        mailMain = Bundle.vpnCore.image(forResource: Image.Name("Mail app logo"))!
        #elseif os(iOS)
        vpnMain = UIImage(named: "VPN app logo", in: Bundle.vpnCore, compatibleWith: nil)!
        driveMain = UIImage(named: "Drive app logo", in: Bundle.vpnCore, compatibleWith: nil)!
        calendarMain = UIImage(named: "Calendar app logo", in: Bundle.vpnCore, compatibleWith: nil)!
        mailMain = UIImage(named: "Mail app logo", in: Bundle.vpnCore, compatibleWith: nil)!
        #endif
    }
}
