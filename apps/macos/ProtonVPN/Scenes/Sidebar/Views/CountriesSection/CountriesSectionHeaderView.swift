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

final class CountriesSectionHeaderView: NSView {

    typealias ActionHandler = () -> Void

    @IBOutlet private weak var titleLbl: NSTextField!
    @IBOutlet private weak var informationBtn: NSButton!

    var didTapInformationButton: ActionHandler?

    override func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = true
    }

    func configure(with viewModel: CountriesServersHeaderViewModelProtocol) {
        titleLbl.stringValue = viewModel.title
        titleLbl.textColor = .color(.text, .hint)

        DarkAppearance {
            layer?.backgroundColor = .cgColor(.background, .weak)
        }

        if viewModel.didTapInfoBtn != nil {
            didTapInformationButton = { [weak viewModel] in
                viewModel?.didTapInfoBtn?()
            }
        } else {
            didTapInformationButton = nil // resetting the property just in case view might get reused
        }

        informationBtn.isHidden = didTapInformationButton == nil
        informationBtn.image = AppTheme.Icon.infoCircleFilled.colored(.hint)
    }

    @IBAction private func didTapInformationBtn(_ sender: Any) {
        didTapInformationButton?()
    }
}
