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

    @IBAction private func connectButtonTap(_ sender: Any) {
        viewModel?.connectAction()
        stateChanged()
    }

    // MARK: Setup

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
        guard let viewModel = viewModel else {
            return
        }

        guard let searchText = searchText, !searchText.isEmpty else {
            cityLabel.text = viewModel.name
            countryLabel.text = viewModel.countryName
            return
        }

        let createText = { (string: String) -> NSAttributedString in
            let text = NSMutableAttributedString(string: string, attributes: [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17),
                NSAttributedString.Key.foregroundColor: colors.weakText
            ])

            string.findStartingRanges(of: searchText).forEach {
                text.addAttributes([NSAttributedString.Key.foregroundColor: colors.text], range: $0)
            }

            return text
        }

        cityLabel.attributedText = createText(viewModel.name)
        countryLabel.attributedText = createText(viewModel.countryName)
    }
}
