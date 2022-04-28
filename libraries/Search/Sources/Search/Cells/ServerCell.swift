//
//  ServerViewCell.swift
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

public protocol ServerCellDelegate: AnyObject {
    func userDidRequestStreamingInfo()
}

public final class ServerCell: UITableViewCell, ConnectTableViewCell {
    public static var identifier: String {
        return String(describing: self)
    }

    public static var nib: UINib {
        return UINib(nibName: identifier, bundle: Bundle.module)
    }

    // MARK: Outlets

    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet private weak var serverNameLabel: UILabel!
    @IBOutlet private weak var cityNameLabel: UILabel!
    @IBOutlet private weak var loadLbl: UILabel!
    @IBOutlet private weak var loadColorView: UIView!
    @IBOutlet private weak var loadContainingView: UIView!

    @IBOutlet private weak var smartIV: UIImageView!
    @IBOutlet private weak var torIV: UIImageView!
    @IBOutlet private weak var p2pIV: UIImageView!
    @IBOutlet private weak var streamingIV: UIImageView!

    @IBOutlet private weak var secureView: UIView!

    @IBOutlet private weak var countryNameLabel: UILabel!
    @IBOutlet private weak var exitFlagIcon: UIImageView!
    @IBOutlet private weak var entryFlagIcon: UIImageView!

    // MARK: Properties

    public weak var delegate: ServerCellDelegate?

    override public func layoutSubviews() {
        super.layoutSubviews()
        connectButton.layer.cornerRadius = mode.cornerRadius
    }

    var searchText: String? {
        didSet {
            setupServerAndCountryName()
        }
    }

    public var viewModel: ConnectViewModel? {
        didSet {
            guard let viewModel = viewModel as? ServerViewModel else {
                return
            }

            backgroundColor = .clear
            selectionStyle = .none
            viewModel.updateTier()
            viewModel.connectionChanged = { [weak self] in self?.stateChanged() }
            serverNameLabel.isHidden = viewModel.entryCountryName != nil
            setupServerAndCountryName()
            cityNameLabel.text = viewModel.displayCityName
            cityNameLabel.isHidden = viewModel.entryCountryName != nil
            secureView.isHidden = viewModel.entryCountryName == nil
            countryNameLabel.isHidden = viewModel.entryCountryName == nil

            smartIV.isHidden = !viewModel.isSmartAvailable
            torIV.isHidden = !viewModel.torAvailable
            p2pIV.isHidden = !viewModel.p2pAvailable
            streamingIV.isHidden = !viewModel.streamingAvailable
            loadContainingView.isHidden = viewModel.underMaintenance || viewModel.isUsersTierTooLow

            loadLbl.text = viewModel.loadValue
            loadColorView.backgroundColor = viewModel.loadColor
            [serverNameLabel, cityNameLabel, torIV, p2pIV, smartIV, streamingIV, secureView].forEach { view in
                view?.alpha = viewModel.alphaOfMainElements
            }

            entryFlagIcon.image = viewModel.entryCountryFlag
            exitFlagIcon.image = viewModel.countryFlag

            DispatchQueue.main.async { [weak self] in
                self?.stateChanged()
            }
        }
    }

    // MARK: Actions

    private func connect() {
        viewModel?.connectAction()
        stateChanged()
    }

    @IBAction private func rowTapped(_ sender: Any, forEvent event: UIEvent) {
        guard let button = sender as? UIButton, let touches = event.touches(for: button), let touch = touches.first, let convertedStreamingView = streamingIV.superview?.convert(streamingIV.frame, to: nil) else {
            connect()
            return
        }

        let touchLocation = touch.location(in: self)
        let margin: CGFloat = 5
        guard convertedStreamingView.origin.x - margin < touchLocation.x, touchLocation.x < convertedStreamingView.origin.x + convertedStreamingView.width + margin else {
            connect()
            return
        }

        delegate?.userDidRequestStreamingInfo()
    }

    @IBAction private func connectButtonTap(_ sender: Any) {
        connect()
    }

    // MARK: Setup

    private func stateChanged() {
        renderConnectButton()
    }

    private func setupServerAndCountryName() {
        guard let viewModel = viewModel as? ServerViewModel else {
            return
        }
        highlightMatches(serverNameLabel, viewModel.description, searchText)
        highlightMatches(countryNameLabel, viewModel.countryName, searchText)
    }
}
