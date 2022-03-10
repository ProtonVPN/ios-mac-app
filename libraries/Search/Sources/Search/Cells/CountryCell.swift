//
//  CountryCell.swift
//  ProtonVPN - Created on 01.07.19.
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

import UIKit

public final class CountryCell: UITableViewCell {
    public static var identifier: String {
        return String(describing: self)
    }

    public static var nib: UINib {
        return UINib(nibName: identifier, bundle: Bundle.module)
    }

    // MARK: Outlets

    @IBOutlet private weak var flagIcon: UIImageView!
    @IBOutlet private weak var countryName: UILabel!

    @IBOutlet private weak var p2pIV: UIImageView!
    @IBOutlet private weak var smartIV: UIImageView!
    @IBOutlet private weak var torIV: UIImageView!

    @IBOutlet private weak var connectButton: UIButton!
    @IBOutlet private var rightMarginConstraint: NSLayoutConstraint!
    @IBOutlet private var rightNoMarginConstraint: NSLayoutConstraint!

    @IBOutlet private weak var entrySeparator: UIImageView!
    @IBOutlet private weak var flagsStackView: UIStackView!
    @IBOutlet private weak var entryFlagIcon: UIImageView!

    // MARK: Properties

    var searchText: String? {
        didSet {
            setupCountryName()
        }
    }

    public var viewModel: CountryViewModel? {
        didSet {
            guard let viewModel = viewModel else {
                return
            }

            viewModel.updateTier()
            viewModel.connectionChanged = { [weak self] in self?.stateChanged() }
            setupCountryName()

            torIV.isHidden = !viewModel.torAvailable
            smartIV.isHidden = !viewModel.isSmartAvailable
            p2pIV.isHidden = !viewModel.p2pAvailable

            backgroundColor = .clear
            flagIcon.image = viewModel.flag
            [flagIcon, countryName, torIV, p2pIV, smartIV, entryFlagIcon].forEach { view in
                view?.alpha = viewModel.alphaOfMainElements
            }
            entryFlagIcon.isHidden = !viewModel.isSecureCoreCountry
            entrySeparator.isHidden = !viewModel.isSecureCoreCountry
            flagsStackView.spacing = viewModel.isSecureCoreCountry ? 8 : 16
            entryFlagIcon.backgroundColor = viewModel.connectButtonColor

            stateChanged()
        }
    }

    // MARK: Actions

    @IBAction private func connectTapped(_ sender: Any) {
        viewModel?.connectAction()
    }

    // MARK: Setup

    override public func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none

        countryName.numberOfLines = 2
        countryName.lineBreakMode = .byTruncatingTail
    }

    private func stateChanged() {
        renderConnectButton()
    }

    private func renderConnectButton() {
        connectButton.backgroundColor = viewModel?.connectButtonColor

        if let text = viewModel?.textInPlaceOfConnectIcon {
            connectButton.setImage(nil, for: .normal)
            connectButton.setTitle(text, for: .normal)
            accessoryType = .none
            rightNoMarginConstraint.isActive = false
            rightMarginConstraint.isActive = true
        } else {
            connectButton.setImage(viewModel?.connectIcon, for: .normal)
            connectButton.setTitle(nil, for: .normal)
            accessoryType = .disclosureIndicator
            rightMarginConstraint.isActive = false
            rightNoMarginConstraint.isActive = true
        }
    }

    private func setupCountryName() {
        guard let viewModel = viewModel else {
            return
        }

        guard let searchText = searchText, !searchText.isEmpty else {
            countryName.text = viewModel.description
            countryName.textColor = viewModel.textColor
            return
        }

        let name = NSMutableAttributedString(string: viewModel.description, attributes: [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17),
            NSAttributedString.Key.foregroundColor: colors.weakText
        ])

        name.addAttributes([NSAttributedString.Key.foregroundColor: viewModel.textColor], range: NSRange(location: 0, length: searchText.count))

        countryName.attributedText = name
    }
}
