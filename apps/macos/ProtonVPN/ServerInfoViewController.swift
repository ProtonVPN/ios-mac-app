//
//  InfoViewController.swift
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

class ServerInfoViewController: NSViewController {
    
    @IBOutlet weak var transparentOverlay: CustomOverlayView!
    @IBOutlet weak var infoView: ServerInfoView!
    @IBOutlet weak var bottonConstraint: NSLayoutConstraint!
    @IBOutlet weak var name: NSTextField!
    @IBOutlet weak var loadLabel: NSTextField!
    @IBOutlet weak var ipLabel: NSTextField!
    @IBOutlet weak var loadValue: NSTextField!
    @IBOutlet weak var loadValueView: LoadCircle!
    @IBOutlet weak var ipValue: NSTextField!
    @IBOutlet weak var secureCoreIcon: NSImageView!
    @IBOutlet weak var secureCoreLabel: NSTextField!
    @IBOutlet weak var p2pIcon: NSImageView!
    @IBOutlet weak var p2pLabel: NSTextField!
    @IBOutlet weak var premiumIcon: NSImageView!
    @IBOutlet weak var premiumLabel: NSTextField!
    @IBOutlet weak var torIcon: NSImageView!
    @IBOutlet weak var torLabel: NSTextField!
    
    private var viewModel: ServerInfoViewModel!
    
    var infoYPosition: CGFloat?
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    required init(viewModel: ServerInfoViewModel) {
        super.init(nibName: NSNib.Name("ServerInfo"), bundle: nil)
        self.viewModel = viewModel
    }
    
    deinit {
        self.dismissPopover()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let infoYPosition = infoYPosition {
            bottonConstraint.constant = infoYPosition
        }
        
        transparentOverlay.clicked = { [weak self] in
            guard let `self` = self else { return }
            self.dismissPopover()
        }
        infoView.clicked = { [weak self] in
            guard let `self` = self else { return }
            self.dismissPopover()
        }
        
        configureView()
    }
    
    func updateView(with viewModel: ServerInfoViewModel) {
        self.viewModel = viewModel
        
        configureView()
    }

    private func configureView() {
        name.attributedStringValue = viewModel.name
        
        loadLabel.attributedStringValue = viewModel.loadLabel
        loadValue.attributedStringValue = viewModel.load
        loadValueView.load = viewModel.loadValue
        
        ipLabel.attributedStringValue = viewModel.ipLabel
        ipValue.attributedStringValue = viewModel.ip.attributed(withColor: NSColor.protonWhite(), fontSize: 12, alignment: .left)
        
        secureCoreLabel.attributedStringValue = viewModel.secureCoreLabel
        secureCoreIcon.image = viewModel.secureCoreImage
        
        p2pLabel.attributedStringValue = viewModel.p2pLabel
        p2pIcon.image = viewModel.p2pImage
        
        premiumLabel.attributedStringValue = viewModel.premiumLabel
        premiumIcon.image = viewModel.premiumImage
        
        torLabel.attributedStringValue = viewModel.torLabel
        torIcon.image = viewModel.torImage
    }
    
    private func dismissPopover() {
        view.removeFromSuperview()
        transparentOverlay.clicked = nil
        infoView.clicked = nil
        removeFromParent()
    }
}
