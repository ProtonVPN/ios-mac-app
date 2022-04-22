//
//  Created on 28/03/2022.
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

public struct NewBrandFeature {
    public let artImage: Image = Asset.newBrandBackground.image
    public let iconImage: Image = Asset.vpnMain.image
    public let title: String = LocalizedString.modalsNewBrandTitle
    public let subtitle: String = LocalizedString.modalsNewBrandSubtitle
    public let gotIt: String = LocalizedString.modalsNewBrandGotIt
    public let readMoreLink: String = "fake-read-more-link" // only used to intercept the tap on URL
    public let learnMore: String = LocalizedString.modalsCommonLearnMore.replacingOccurrences(of: " ", with: "\u{00a0}") // non-breaking space

    public init() { }
}

public protocol NewBrandIcons {
    var vpnMain: Image { get }
    var driveMain: Image { get }
    var calendarMain: Image { get }
    var mailMain: Image { get }
}

extension NSMutableAttributedString {
    public func setAsLink(textToFind: String, linkURL: String) {
        let foundRange = mutableString.range(of: textToFind)
        if foundRange.location != NSNotFound {
            addAttribute(.link, value: linkURL, range: foundRange)
        }
    }
}
