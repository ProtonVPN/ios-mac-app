//
//  StatusMenuProfileViewItem.swift
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
import Ergonomics
import ProtonCoreUIFoundations

class StatusMenuProfileViewItem: NSTableRowView {
    @IBOutlet var profileCircle: ProfileCircle!
    @IBOutlet var profileImage: NSImageView!
    @IBOutlet var label: NSTextField!
    @IBOutlet var secondaryLabel: NSTextField!
    @IBOutlet var separator: NSBox!
    @IBOutlet var button: StatusMenuSurfaceButton!

    private var viewModel: StatusMenuProfileItemViewModel?

    func updateView(withModel viewModel: StatusMenuProfileItemViewModel) {
        self.viewModel = viewModel

        setupIcon()
        setupLabels()
        setupSeparator()
        setupButton()
        setupAvailability()
    }

    @IBAction
    func selected(_: Any) {
        viewModel?.connectAction()
    }

    // MARK: - Private

    private func setupIcon() {
        guard let viewModel else { return }

        switch viewModel.icon {
        case .bolt:
            profileImage.image = IconProvider.bolt.colored()
            profileImage.isHidden = false
            profileCircle.isHidden = true
        case .arrowsSwapRight:
            profileImage.image = IconProvider.arrowsSwapRight.colored()
            profileImage.isHidden = false
            profileCircle.isHidden = true
        case let .circle(color):
            profileCircle.profileColor = NSColor(rgbHex: color)
            profileImage.isHidden = true
            profileCircle.isHidden = false
        }
    }

    private func setupLabels() {
        guard let viewModel else { return }

        label.attributedStringValue = viewModel.name
        secondaryLabel.attributedStringValue = viewModel.secondaryDescription
    }

    private func setupSeparator() {
        separator.fillColor = .color(.border, .strong)
    }

    private func setupButton() {
        button.stateChanged = { [weak self] in
            guard let self else {
                return
            }

            DarkAppearance {
                if self.button.isHovered, let viewModel = self.viewModel, viewModel.canConnect {
                    self.button.layer?.backgroundColor = .cgColor(.background, [.transparent, .hovered])
                } else {
                    self.button.layer?.backgroundColor = .cgColor(.background, [.transparent])
                }
            }
            button.needsDisplay = true
        }
    }

    private func setupAvailability() {
        for view in [profileImage, profileCircle, label, secondaryLabel] {
            view?.alphaValue = viewModel?.alphaOfMainElements ?? 1
        }
    }
}
