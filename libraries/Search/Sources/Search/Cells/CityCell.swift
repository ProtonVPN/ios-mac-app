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

final class CityCell: UITableViewCell, ConnectTableViewCell {
    static var identifier: String {
        return String(describing: self)
    }

    static var nib: UINib {
        return UINib(nibName: identifier, bundle: Bundle.module)
    }

    // MARK: Outlets

    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet private weak var countryLabel: UILabel!
    @IBOutlet private weak var cityLabel: UILabel!
    @IBOutlet private weak var flagImageView: UIImageView!

    // MARK: Properties

    var searchText: String? {
        didSet {
            setupCityAndCountryName()
        }
    }

    public var viewModel: ConnectViewModel? {
        didSet {
            guard var viewModel = viewModel as? CityViewModel else {
                return
            }
            flagImageView.image = viewModel.countryFlag
            setupCityAndCountryName()
            viewModel.connectionChanged = { [weak self] in self?.stateChanged() }

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
        connectButton.addInteraction(UIPointerInteraction(delegate: self))
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        connectButton.layer.cornerRadius = mode.cornerRadius
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

    private func setupCityAndCountryName() {
        guard let viewModel = viewModel as? CityViewModel else {
            return
        }
        highlightMatches(cityLabel, viewModel.displayCityName, searchText)
        highlightMatches(countryLabel, viewModel.countryName, searchText)
    }
}

extension CityCell: UIPointerInteractionDelegate {
    public func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        var pointerStyle: UIPointerStyle? = nil
        if let interactionView = interaction.view {
            let targetedPreview = UITargetedPreview(view: interactionView)
            pointerStyle = UIPointerStyle(effect: UIPointerEffect.lift(targetedPreview))
        }
        return pointerStyle
    }
}
