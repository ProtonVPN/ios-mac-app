//
//  Created on 03.03.2022.
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
import UIKit

public protocol CountryViewModel: AnyObject {
    var description: String { get }
    var isSmartAvailable: Bool { get }
    var torAvailable: Bool { get }
    var p2pAvailable: Bool { get }
    var connectIcon: UIImage? { get }
    var textInPlaceOfConnectIcon: String? { get }
    var connectionChanged: (() -> Void)? { get set }
    var alphaOfMainElements: CGFloat { get }
    var flag: UIImage? { get }
    var connectButtonColor: UIColor { get }
    var textColor: UIColor { get }

    func updateTier()
    func connectAction()
    func getServers() -> [ServerTier: [ServerViewModel]]
}
