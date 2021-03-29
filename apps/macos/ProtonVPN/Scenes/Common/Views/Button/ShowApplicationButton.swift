//
//  GreenActionButton.swift
//  ProtonVPN - Created on 27.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Cocoa
import vpncore

class ShowApplicationButton: HoverDetectionButton {
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)

        configureView()
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        
        configureView()
    }
    
    private func configureView() {
        let secureCoreIcon = NSAttributedString.imageAttachment(named: "protonvpn-server-sc-available", width: 13, height: 13, colored: isHovered ? .protonGreenHighlight() : nil)!
        let show = (" " + LocalizedString.showProtonVpn).attributed(withColor: isHovered ? .protonGreenHighlight() : .protonGreen(), fontSize: 14)
        attributedTitle = NSAttributedString.concatenate(secureCoreIcon, show)
    }
}
