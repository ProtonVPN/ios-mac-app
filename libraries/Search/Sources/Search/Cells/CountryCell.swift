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

public final class CountryCell: ConnectTableViewCell {
    public static var identifier: String {
        return String(describing: self)
    }

    public static var nib: UINib {
        return UINib(nibName: identifier, bundle: Bundle.module)
    }

    static let chevronRight = UIImage(named: "ic-chevron-right", in: .module, compatibleWith: nil)

    // MARK: Outlets

    @IBOutlet private weak var flagIcon: UIImageView!
    @IBOutlet private weak var countryName: UILabel!

    @IBOutlet private weak var p2pIV: UIImageView!
    @IBOutlet private weak var smartIV: UIImageView!
    @IBOutlet private weak var torIV: UIImageView!

    @IBOutlet private var rightMarginConstraint: NSLayoutConstraint!
    @IBOutlet private var rightNoMarginConstraint: NSLayoutConstraint!

    @IBOutlet private weak var entrySeparator: UIImageView!
    @IBOutlet private weak var flagsStackView: UIStackView!

    // MARK: Properties

    var searchText: String? {
        didSet {
            guard let viewModel = viewModel as? CountryViewModel else {
                return
            }
            highlightMatches(countryName, viewModel.description, searchText)
        }
    }

    override public var viewModel: ConnectViewModel? {
        didSet {
            guard let viewModel = viewModel as? CountryViewModel else {
                return
            }

            viewModel.updateTier()
            viewModel.connectionChanged = { [weak self] in self?.stateChanged() }
            countryName.textColor = viewModel.textColor
            highlightMatches(countryName, viewModel.description, searchText)

            torIV.isHidden = !viewModel.torAvailable
            smartIV.isHidden = !viewModel.isSmartAvailable
            p2pIV.isHidden = !viewModel.p2pAvailable

            backgroundColor = .clear
            flagIcon.image = viewModel.flag
            [flagIcon, countryName, torIV, p2pIV, smartIV].forEach { view in
                view?.alpha = viewModel.alphaOfMainElements
            }
            entrySeparator.isHidden = !viewModel.isSecureCoreCountry
            flagsStackView.spacing = viewModel.isSecureCoreCountry ? 8 : 16

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
        updateAccessoryView()
    }

    func updateAccessoryView() {
        if viewModel?.textInPlaceOfConnectIcon != nil {
            accessoryType = .none
            accessoryView = nil
            rightNoMarginConstraint.isActive = false
            rightMarginConstraint.isActive = true
        } else {
            let chevronRight = UIImageView(image: CountryCell.chevronRight)
            chevronRight.tintColor = UIColor(red: 167 / 255, green: 164 / 255, blue: 181 / 255, alpha: 1) // colors.iconWeak
            chevronRight.sizeToFit()
            accessoryView = chevronRight
            rightMarginConstraint.isActive = false
            rightNoMarginConstraint.isActive = true
        }
    }
}
