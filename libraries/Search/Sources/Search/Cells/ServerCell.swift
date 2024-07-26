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

    static let featureViewTag = "Tag For Server Features Icons".hashValue

    private enum ServerFeature {
        case smart
        case tor
        case streaming
        case p2p

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
            viewModel.connectionChanged = { [weak self] in self?.stateChanged() }
            serverNameLabel.isHidden = viewModel.entryCountryName != nil
            setupServerAndCountryName()
            cityNameLabel.text = viewModel.displayCityName
            cityNameLabel.isHidden = viewModel.entryCountryName != nil
            secureView.isHidden = viewModel.entryCountryName == nil
            countryNameLabel.isHidden = viewModel.entryCountryName == nil

            configureFeaturesStackView(viewModel: viewModel)

            loadContainingView.isHidden = viewModel.underMaintenance || viewModel.isUsersTierTooLow

            loadLbl.text = "\(viewModel.load)%"
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
        if viewModel.isP2PAvailable {
            addFeature(feature: .p2p)
        }
        if viewModel.isTorAvailable {
            addFeature(feature: .tor)
        }
        if viewModel.isSmartAvailable {
            addFeature(feature: .smart)
        }
        if viewModel.isStreamingAvailable {
            addFeature(feature: .streaming)
        }
    }

    private func addFeature(feature: ServerFeature) {
        switch feature {
        case .smart, .tor, .p2p:
            featuresStackView.addArrangedSubview(imageViewForFeature(feature: feature))
        case .streaming:
            let streamingIV = imageViewForFeature(feature: feature)
            featuresStackView.addArrangedSubview(streamingIV)
            self.streamingIV = streamingIV
        }
    }

    private func imageViewForFeature(feature: ServerFeature, iconSize: CGFloat? = 16) -> UIImageView {
        let imageView = UIImageView(image: UIImage(named: feature.imageName,
                                                   in: .module,
                                                   with: nil))
        imageView.tag = ServerCell.featureViewTag
        imageView.tintColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        if let iconSize {
            imageView.addConstraints([
                imageView.widthAnchor.constraint(equalToConstant: iconSize),
                imageView.heightAnchor.constraint(equalToConstant: iconSize)
            ])
        }
        return imageView
    }

    override public func awakeFromNib() {
        super.awakeFromNib()

        connectButton.addInteraction(UIPointerInteraction(delegate: self))
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        featuresStackView
            .subviews
            .filter { $0.tag == ServerCell.featureViewTag }
            .forEach { $0.removeFromSuperview() }
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
        if isViewTapped(streamingIV, touch: touch) {
            delegate?.userDidRequestStreamingInfo()
        } else {
            connect()
        }
    }

    private func tappedOnPartner(touch: UITouch) -> Bool {
        partnersImageViews.contains {
            isViewTapped($0, touch: touch)
        }
    }

    private func isViewTapped(_ view: UIView?, touch: UITouch) -> Bool {
        guard let view else { return false }
        let padding: CGFloat = 10
        return view
            .superview?
            .convert(view.frame, to: self)
            .insetBy(dx: -padding, dy: -padding)
            .contains(touch.location(in: self)) ?? false
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
