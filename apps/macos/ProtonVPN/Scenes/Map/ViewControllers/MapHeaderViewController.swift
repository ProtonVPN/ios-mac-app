//
//  MapHeaderViewController.swift
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

class MapHeaderViewController: NSViewController {

    @IBOutlet weak var backgroundView: MapHeaderBackground!
    @IBOutlet weak var connectLabel: NSTextField!
    @IBOutlet weak var connectImage: ButtonImageView!
    
    private var viewModel: MapHeaderViewModel!
    
    var headerClicked: (() -> Void)? {
        didSet {
            connectImage.imageClicked = { [unowned self] in self.headerClicked?() }
            backgroundView.clicked = { [unowned self] in self.headerClicked?() }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    required init(viewModel: MapHeaderViewModel) {
        super.init(nibName: NSNib.Name("MapHeader"), bundle: nil)
        self.viewModel = viewModel
        viewModel.contentChanged = { [unowned self] in self.setupEphemeralView() }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupPersistentView()
        setupEphemeralView()
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        if backgroundView.frame.width < backgroundView.width && !view.isHidden {
            backgroundView.isHidden = true
        } else if backgroundView.isHidden {
            backgroundView.isHidden = false
        }
    }
    
    private func setupPersistentView() {
        connectImage.image = NSImage(named: NSImage.Name("home"))
    }
    
    private func setupEphemeralView() {
        backgroundView.isConnected = viewModel.isConnected
        connectLabel.attributedStringValue = viewModel.description
    }
}
