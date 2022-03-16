//
//  FeaturesOverlayViewController.swift
//  ProtonVPN - Created on 22.04.21.
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
import vpncore
import ProtonCore_UIFoundations

class FeaturesOverlayViewController: NSViewController {

    @IBOutlet private weak var smartRoutingRow: FeatureRowView!
    @IBOutlet private weak var streamingRow: FeatureRowView!
    @IBOutlet private weak var p2pRow: FeatureRowView!
    @IBOutlet private weak var torRow: FeatureRowView!
    @IBOutlet private weak var featuresTitleTF: NSTextField!
    
    private let viewModel: FeaturesOverlayViewModelProtocol
    
    init(viewModel: FeaturesOverlayViewModelProtocol) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        featuresTitleTF.stringValue = viewModel.title
        smartRoutingRow.viewModel = viewModel.smartRoutingViewModel
        streamingRow.viewModel = viewModel.streamingViewModel
        p2pRow.viewModel = viewModel.p2pViewModel
        torRow.viewModel = viewModel.torViewModel
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.protonUpsellBlack().cgColor
    }
    
    // MARK: - Actions
    
    @IBAction func didTapDismissBtn(_ sender: Any) {
        dismiss(self)
    }
}
