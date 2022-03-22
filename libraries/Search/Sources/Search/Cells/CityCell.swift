//
//  Created on 16.03.2022.
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

import UIKit

final class CityCell: UITableViewCell {
    static var identifier: String {
        return String(describing: self)
    }

    static var nib: UINib {
        return UINib(nibName: identifier, bundle: Bundle.module)
    }

    // MARK: Outlets

    @IBOutlet private weak var countryLabel: UILabel!
    @IBOutlet private weak var cityLabel: UILabel!
    @IBOutlet private weak var flagImageView: UIImageView!
    @IBOutlet private weak var connectButton: UIButton!

    // MARK: Properties

    var searchText: String? {
        didSet {
            setupCityAndCountryName()
        }
    }

    public var viewModel: CityViewModel? {
        didSet {
            flagImageView.image = viewModel?.countryFlag
            setupCityAndCountryName()
            viewModel?.updateTier()
            viewModel?.connectionChanged = { [weak self] in self?.stateChanged() }

            DispatchQueue.main.async { [weak self] in
                self?.stateChanged()
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = .clear
        selectionStyle = .none
        countryLabel.textColor = colors.weakText
        cityLabel.textColor = colors.weakText
    }

    // MARK: Actions

    private func connect() {
        viewModel?.connectAction()
        stateChanged()
    }

    @IBAction private func connectButtonTap(_ sender: Any) {
        connect()
    }

    // MARK: Setup

    @IBAction private func rowTapped(_ sender: Any, forEvent event: UIEvent) {
        connect()
    }

    private func stateChanged() {
        renderConnectButton()
    }

    private func renderConnectButton() {
        connectButton.backgroundColor = viewModel?.connectButtonColor

        if let text = viewModel?.textInPlaceOfConnectIcon {
            connectButton.setImage(nil, for: .normal)
            connectButton.setTitle(text, for: .normal)
        } else {
            connectButton.setImage(viewModel?.connectIcon, for: .normal)
            connectButton.setTitle(nil, for: .normal)
        }
    }

    private func setupCityAndCountryName() {
        highlightMatches(cityLabel, viewModel?.displayCityName, searchText)
        highlightMatches(countryLabel, viewModel?.countryName, searchText)
    }
}
