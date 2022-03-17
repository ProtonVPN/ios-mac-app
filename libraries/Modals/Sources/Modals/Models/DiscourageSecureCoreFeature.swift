//
//  Created on 08/03/2022.
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

public struct DiscourageSecureCoreFeature {
    public let artImage: Image = Asset.secureCoreDiscourage.image
    public let title: String = LocalizedString.modalsDiscourageSecureCoreTitle
    public let subtitle: String = LocalizedString.modalsDiscourageSecureCoreSubtitle
    public let learnMore: String = LocalizedString.modalsCommonLearnMore
    public let dontShow: String = LocalizedString.modalsDiscourageSecureCoreDontShow
    public let activate: String = LocalizedString.modalsDiscourageSecureCoreActivate
    public let cancel: String = LocalizedString.modalsCommonCancel

    public init() { }
}
