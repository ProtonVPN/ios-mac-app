//
//  Created on 26/04/2022.
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

import AppKit
import LegacyCommon
import Strings

class LoadingView: NSView {
    @IBOutlet private weak var loadingSymbol: LoadingAnimationView!
    @IBOutlet private weak var loadingLabel: PVPNTextField! {
        didSet {
            let font = NSFont.themeFont(.heading3)
            loadingLabel.attributedStringValue = Localizable.loadingScreenSlogan.styled(font: font)
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        isHidden = true
        clipToBounds()
    }

    func animate(_ animate: Bool) {
        isHidden = !animate
        loadingSymbol.animate(animate)
    }
}
