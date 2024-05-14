//
//  ServerItemCellView.swift
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
import LegacyCommon
import Theme
import Ergonomics
import Strings

protocol ServerItemCellViewDelegate: AnyObject {
    func userDidRequestStreamingInfo(server: ServerItemViewModel)
}

final class ServerItemCellView: NSView {
    
    @IBOutlet private weak var loadIcon: ColoredLoadButton!

    @IBOutlet private weak var serverInfoStackView: NSStackView!
    private weak var featuresStackView: NSStackView!

    @IBOutlet private weak var serverLbl: NSTextField!
    @IBOutlet private weak var cityLbl: NSTextField!
    @IBOutlet private weak var secureCoreIV: NSImageView!
    @IBOutlet private weak var secureFlagIV: NSImageView!
    @IBOutlet private weak var connectBtn: ConnectButton!
    @IBOutlet private weak var maintenanceIV: NSButton!
    @IBOutlet private weak var upgradeBtn: NSButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = true
        DarkAppearance {
            layer?.backgroundColor = .cgColor(.background, .weak)
        }
        upgradeBtn.stringValue = Localizable.upgrade

        let imageMargin = 8
        maintenanceIV.wantsLayer = true
        maintenanceIV.layer?.cornerRadius = maintenanceIV.bounds.height / 2
        maintenanceIV.layer?.backgroundColor = .clear
        maintenanceIV.layer?.borderColor = .cgColor(.icon, .weak)
        maintenanceIV.layer?.borderWidth = 2.0
        maintenanceIV.image = AppTheme.Icon.wrench
            .colored(.weak)
            .resize(newWidth: Int(maintenanceIV.bounds.width) - imageMargin,
                    newHeight: Int(maintenanceIV.bounds.height) - imageMargin)

        secureCoreIV.image = AppTheme.Icon.chevronsRight.colored([.interactive, .strong])

        let trackingFrame = NSRect(origin: frame.origin, size: CGSize(width: frame.size.width, height: frame.size.height - 12))
        let trackingArea = NSTrackingArea(rect: trackingFrame,
                                          options: [.mouseEnteredAndExited, .activeInKeyWindow],
                                          owner: self,
                                          userInfo: nil)
        addTrackingArea(trackingArea)

        connectBtn.wantsLayer = true
        let featuresStackView = NSStackView()
        featuresStackView.translatesAutoresizingMaskIntoConstraints = false
        featuresStackView.orientation = .horizontal
        featuresStackView.alignment = .centerY
        featuresStackView.distribution = .fill
        featuresStackView.spacing = .UI.halfMargin
        addSubview(featuresStackView, positioned: .below, relativeTo: connectBtn)
        addConstraints([serverInfoStackView.trailingAnchor.constraint(equalTo: featuresStackView.leadingAnchor, constant: -.UI.halfMargin),
                        serverInfoStackView.centerYAnchor.constraint(equalTo: featuresStackView.centerYAnchor),
                        featuresStackView.heightAnchor.constraint(equalToConstant: .UI.iconSize)])
        self.featuresStackView = featuresStackView
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        featuresStackView.subviews.forEach {
            ($0 as? NSButton)?.sd_cancelCurrentImageLoad()
            ($0 as? NSImageView)?.sd_cancelCurrentImageLoad()
            $0.removeFromSuperview()
        }
    }

    func addFeatures() {
        if viewModel.isSmartAvailable {
            let imageView = NSImageView(image: AppTheme.Icon.globe.colored(.weak))
            addViewToFeaturesStack(imageView)
        }

        if viewModel.isP2PAvailable {
            let imageView = NSImageView(image: AppTheme.Icon.arrowsSwitch.colored(.weak))
            addViewToFeaturesStack(imageView)
        }

        if viewModel.isTorAvailable {
            let imageView = NSImageView(image: AppTheme.Icon.brandTor.colored(.weak))
            addViewToFeaturesStack(imageView)
        }

        if viewModel.isStreamingAvailable {
            let button = NSButton(image: AppTheme.Icon.play.colored(.weak), target: self, action: #selector(didTapStreaming))
            button.isBordered = false
            addViewToFeaturesStack(button)
        }
    }

    func addViewToFeaturesStack(_ view: NSView, width: CGFloat = .UI.margin) {
        view.translatesAutoresizingMaskIntoConstraints = false
        view.addConstraint(view.widthAnchor.constraint(equalToConstant: width))
        view.wantsLayer = true
        featuresStackView.addArrangedSubview(view)
    }
    
    private var viewModel: ServerItemViewModel!
    
    var disabled: Bool = false

    weak var delegate: ServerItemCellViewDelegate?

    override func mouseEntered(with event: NSEvent) {
        if disabled || viewModel.underMaintenance || viewModel.isUsersTierTooLow {
            mouseExited(with: event)
            return
        }
        cityLbl.isHidden = true
        connectBtn.isHidden = false
    }
    
    override func mouseExited(with event: NSEvent) {
        upgradeBtn.isHidden = !viewModel.isUsersTierTooLow
        cityLbl.isHidden = viewModel.isConnected || viewModel.isUsersTierTooLow
        connectBtn.isHidden = !viewModel.isConnected || viewModel.isUsersTierTooLow
    }
    
    func updateView(withModel viewModel: ServerItemViewModel) {
        self.viewModel = viewModel
        loadIcon.load = viewModel.load
        loadIcon.isHidden = viewModel.underMaintenance
        maintenanceIV.isHidden = !viewModel.underMaintenance
        secureFlagIV.isHidden = !viewModel.isSecureCoreEnabled
        secureCoreIV.isHidden = !viewModel.isSecureCoreEnabled
        serverLbl.stringValue = viewModel.serverName
        cityLbl.stringValue = viewModel.cityName
        connectBtn.isConnected = viewModel.isConnected
        connectBtn.isHidden = !viewModel.isConnected || viewModel.isUsersTierTooLow
        cityLbl.isHidden = viewModel.isConnected || viewModel.isUsersTierTooLow
        connectBtn.isHovered = false
        upgradeBtn.isHidden = !viewModel.isUsersTierTooLow
        setupInfoView()

        addFeatures()
        
        [loadIcon, maintenanceIV, secureFlagIV, secureCoreIV, serverLbl, cityLbl].forEach {
            $0?.alphaValue = viewModel.alphaOfMainElements
        }

        featuresStackView.views.forEach {
            $0.alphaValue = viewModel.alphaOfMainElements
        }
                
        if let code = viewModel.entryCountry {
            secureFlagIV.image = AppTheme.Icon.flag(countryCode: code)
        }
        
        setupAccessibility()
    }

    // MARK: - Private functions

    private func setupInfoView() {
        let isUnderMaintenance = viewModel.underMaintenance
        maintenanceIV.isHidden = !isUnderMaintenance
        loadIcon.isHidden = isUnderMaintenance
    }
    
    @IBAction private func didTapConnectBtn(_ sender: Any) {
        viewModel.connectAction()
    }
    
    @IBAction private func didTapUpgradeBtn(_ sender: Any) {
        viewModel.upgradeAction()
    }

    @objc private func didTapStreaming(_ sender: Any) {
        delegate?.userDidRequestStreamingInfo(server: viewModel)
    }

    // MARK: - Accessibility
    private func setupAccessibility() {
        setAccessibilityLabel(viewModel.accessibilityLabel)
        connectBtn.nameForAccessibility = viewModel.serverName
        connectBtn.setAccessibilityElement(true)
    }
    
    override func accessibilityChildren() -> [Any]? {
        return [connectBtn as Any]
    }
}
