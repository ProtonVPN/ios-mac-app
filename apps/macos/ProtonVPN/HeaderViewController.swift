//
//  HeaderViewController.swift
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

class HeaderViewController: NSViewController {

    @IBOutlet weak var backgroundView: NSView!
    @IBOutlet weak var flagView: FlagView!
    @IBOutlet weak var headerLabel: NSTextField!
    @IBOutlet weak var ipLabel: NSTextField!
    @IBOutlet weak var loadLabel: NSTextField!
    @IBOutlet weak var loadIcon: LoadCircle!
    @IBOutlet weak var profileButton: GreenActionButton!
    @IBOutlet weak var speedLabel: NSTextField!
    @IBOutlet weak var connectButton: LargeConnectButton!
    @IBOutlet weak var loadLineHorizontalConstraint1: NSLayoutConstraint!
    @IBOutlet weak var loadLineHorizontalConstraint2: NSLayoutConstraint!
    @IBOutlet weak var loadLineHorizontalConstraint3: NSLayoutConstraint!
    @IBOutlet weak var loadLineHorizontalConstraint4: NSLayoutConstraint!
    
    private var loadLineHorizontalConstraints: [NSLayoutConstraint] {
        return [loadLineHorizontalConstraint1, loadLineHorizontalConstraint2, loadLineHorizontalConstraint3, loadLineHorizontalConstraint4]
    }
    
    private var viewModel: HeaderViewModel!
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    required init(viewModel: HeaderViewModel) {
        super.init(nibName: NSNib.Name("Header"), bundle: nil)
        self.viewModel = viewModel
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewModel.delegate = self
        setupPersistentView()
        setupEphemeralView()
        viewModel.contentChanged = { [unowned self] in self.setupEphemeralView() }
    }
    
    private func setupPersistentView() {
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor.protonDarkGrey().cgColor
        
        profileButton.target = self
        profileButton.action = #selector(profileButtonAction)
        
        connectButton.target = self
        connectButton.action = #selector(quickConnectButtonAction)
    }
    
    private func setupEphemeralView() {
        setupFlagView()
        
        headerLabel.attributedStringValue = viewModel.headerLabel
        ipLabel.attributedStringValue = viewModel.ipLabel
        
        setupLoad()
        setupBitrate()
        setupProfileButton()
        
        connectButton.isConnected = viewModel.isConnected
    }
    
    private func setupFlagView() {
        if viewModel.isConnected, let countryCode = viewModel.connectedCountryCode?.lowercased() {
            flagView.backgroundImage = NSImage(named: NSImage.Name("\(countryCode)-large"))
        } else if !viewModel.isConnected && flagView.backgroundImage != nil {
            flagView.backgroundImage = nil
        }
    }
    
    private func setupLoad() {
        if viewModel.isConnected, let loadDescription = viewModel.loadLabel, let loadDescriptionShort = viewModel.loadLabelShort, let loadPercentage = viewModel.loadPercentage {
            loadLabel.attributedStringValue = loadDescription // Preset with full description for `loadLineType` to work correctly
            loadLabel.toolTip = ""
            if loadLineType == .short {
                loadLabel.attributedStringValue = loadDescriptionShort
                loadLabel.toolTip = loadDescription.string
            }
            loadLabel.isHidden = false
            loadIcon.load = loadPercentage
            loadIcon.toolTip = loadDescription.string
            loadIcon.isHidden = false
        } else {
            loadLabel.isHidden = true
            loadIcon.isHidden = true
        }
    }
    
    private func setupBitrate() {
        if viewModel.isConnected {
            speedLabel.isHidden = false
        } else {
            speedLabel.isHidden = true
        }
    }
    
    private func setupProfileButton() {
        if viewModel.isConnected, let title = viewModel.profileButtonLabel {
            profileButton.attributedTitle = title
            profileButton.isHidden = false
        } else {
            profileButton.isHidden = true
        }
    }
    
    @objc private func profileButtonAction() {
        viewModel.profileAction()
    }
    
    @objc private func quickConnectButtonAction() {
        viewModel.quickConnectAction()
    }
    
    // MARK: Load line
    
    private enum LineType {
        case full
        case short
    }
    
    private var loadLineType: LineType {
        let margins = loadLineHorizontalConstraints.reduce(0.0) { $0 + $1.constant }
        let width = margins + ipLabel.intrinsicContentSize.width + loadLabel.intrinsicContentSize.width + loadIcon.frame.width
        
        debugPrint(margins, ipLabel.intrinsicContentSize.width, loadLabel.intrinsicContentSize.width, loadIcon.frame.width, width, self.view.frame.width)
        if width + 10 > self.view.frame.width {
            return .short
        }
        return .full
    }
    
}

extension HeaderViewController: HeaderViewModelDelegate {
    
    func bitrateUpdated(with attributedString: NSAttributedString) {
        speedLabel.attributedStringValue = attributedString
    }
}
