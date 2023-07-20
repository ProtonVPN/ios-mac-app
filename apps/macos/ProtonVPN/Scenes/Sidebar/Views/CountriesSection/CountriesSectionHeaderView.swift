//
//  CountriesSectionHeaderView.swift
//  ProtonVPN - Created on 27.04.21.
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
import Theme
import Ergonomics

class CountriesSectionHeaderView: NSView {

    @IBOutlet private weak var titleLbl: NSTextField!
    @IBOutlet private weak var informationBtn: NSButton!
    
    @IBAction private func didTapInformationBtn(_ sender: Any) {
        viewModel?.didTapInfoBtn?()
    }
    
    var viewModel: CountriesServersHeaderViewModelProtocol? {
        didSet {
            wantsLayer = true
            titleLbl.stringValue = viewModel?.title ?? ""
            titleLbl.textColor = .color(.text, .hint)
            DarkAppearance {
                layer?.backgroundColor = .cgColor(.background, .weak)
            }
            informationBtn.isHidden = viewModel?.didTapInfoBtn == nil
            informationBtn.image = AppTheme.Icon.infoCircleFilled.colored(.hint)
        }
    }
}
