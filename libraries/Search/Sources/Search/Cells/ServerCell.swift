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
    func userDidRequestFreeServersInfo()
}

public final class ServerCell: UITableViewCell, ConnectTableViewCell {
    public static var identifier: String {
        return String(describing: self)
    }

    public static var nib: UINib {
        return UINib(nibName: identifier, bundle: Bundle.module)
    }

    private enum ServerFeature {
        case smart
        case tor
        case streaming
        case p2p
        case partner(UIImage)

        var imageName: String {
            switch self {
            case .smart:
                return "ic-globe"
            case .tor:
                return "ic-brand-tor"
            case .streaming:
                return "ic-play"
            case .p2p:
                return "ic-arrows-switch"
            default:
                return ""
            }
        }
    }

    // MARK: Outlets

    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet private weak var serverNameLabel: UILabel!
    @IBOutlet private weak var cityNameLabel: UILabel!
    @IBOutlet private weak var loadLbl: UILabel!
    @IBOutlet private weak var loadColorView: UIView!
    @IBOutlet private weak var loadContainingView: UIView!

    private var partnersImageViews: [UIImageView] = []
    private var smartIV: UIImageView?
    private var torIV: UIImageView?
    private var p2pIV: UIImageView?
    private var streamingIV: UIImageView?
    @IBOutlet private weak var featuresStackView: UIStackView!

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

            configureFeaturesStackView(viewModel: viewModel)

            loadContainingView.isHidden = viewModel.underMaintenance || viewModel.isUsersTierTooLow

            loadLbl.text = viewModel.loadValue
            loadColorView.backgroundColor = viewModel.loadColor
            [serverNameLabel, cityNameLabel, secureView].forEach { view in
                view?.alpha = viewModel.alphaOfMainElements
            }

            entryFlagIcon.image = viewModel.entryCountryFlag
            exitFlagIcon.image = viewModel.countryFlag

            DispatchQueue.main.async { [weak self] in
                self?.stateChanged()
            }
        }
    }

    private func configureFeaturesStackView(viewModel: ServerViewModel) {
        if viewModel.p2pAvailable {
            addFeature(feature: .p2p)
        }
        if viewModel.torAvailable {
            addFeature(feature: .tor)
        }
        if viewModel.isSmartAvailable {
            addFeature(feature: .smart)
        }
        if viewModel.streamingAvailable {
            addFeature(feature: .streaming)
        }
        viewModel.partnersIcon { [weak self] image in
            guard let image else { return }
            self?.addFeature(feature: .partner(image))
        }
    }

    private func addFeature(feature: ServerFeature) {
        let imageView = UIImageView(image: UIImage(named: feature.imageName,
                                                   in: .module,
                                                   with: nil))
        imageView.tintColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.addConstraints([
            imageView.widthAnchor.constraint(equalToConstant: 16),
            imageView.heightAnchor.constraint(equalToConstant: 16)
        ])
        switch feature {
        case .smart:
            self.smartIV = imageView
            featuresStackView.addArrangedSubview(imageView)
        case .tor:
            self.torIV = imageView
            featuresStackView.addArrangedSubview(imageView)
        case .streaming:
            self.streamingIV = imageView
            featuresStackView.addArrangedSubview(imageView)
        case .p2p:
            self.p2pIV = imageView
        case .partner(let image):
            imageView.image = image
            imageView.removeConstraints(imageView.constraints)
            self.partnersImageViews.append(imageView)
            featuresStackView.insertArrangedSubview(imageView, at: 0)
        }
    }

    override public func awakeFromNib() {
        super.awakeFromNib()

        connectButton.addInteraction(UIPointerInteraction(delegate: self))
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        (viewModel as? ServerViewModel)?.cancelPartnersIconRequests()
    }

    // MARK: Actions

    private func connect() {
        viewModel?.connectAction()
        stateChanged()
    }

    @IBAction private func rowTapped(_ button: UIButton, forEvent event: UIEvent) {
        guard let touch = event.touches(for: button)?.first else {
            connect()
            return
        }
        if let streamingIV, isViewTapped(streamingIV, touch: touch) {
            delegate?.userDidRequestStreamingInfo()
            return
        }
        let tappedOnPartner = partnersImageViews.contains {
            isViewTapped($0, touch: touch)
        }
        if tappedOnPartner {
            delegate?.userDidRequestFreeServersInfo()
            return
        }
        connect()
    }

    private func isViewTapped(_ imageView: UIView, touch: UITouch) -> Bool {
        guard let convertedStreamingView = imageView.superview?.convert(imageView.frame, to: nil) else {
            return false
        }

        let touchLocation = touch.location(in: self)
        let margin: CGFloat = 5
        guard convertedStreamingView.origin.x - margin < touchLocation.x,
              touchLocation.x < convertedStreamingView.origin.x + convertedStreamingView.width + margin else {
            return false
        }

        return true
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

extension ServerCell: UIPointerInteractionDelegate {
    public func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        var pointerStyle: UIPointerStyle? = nil
        if let interactionView = interaction.view {
            let targetedPreview = UITargetedPreview(view: interactionView)
            pointerStyle = UIPointerStyle(effect: UIPointerEffect.lift(targetedPreview))
        }
        return pointerStyle
    }
}
