//
//  StatusMenuProfileItem.swift
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

class StatusMenuProfileViewItem: NSTableRowView {
    
    @IBOutlet weak var profileCircle: ProfileCircle!
    @IBOutlet weak var profileImage: NSImageView!
    @IBOutlet weak var label: NSTextField!
    @IBOutlet weak var secondaryLabel: NSTextField!
    @IBOutlet weak var seperator: NSBox!
    @IBOutlet weak var button: StatusMenuSurfaceButton!
    
    private var viewModel: StatusMenuProfileItemViewModel?
    
    func updateView(withModel viewModel: StatusMenuProfileItemViewModel) {
        self.viewModel = viewModel
        
        setupIcon()
        setupLabels()
        setupSeperator()
        setupButton()
        setupAvailability()
    }
    
    @IBAction func selected(_ sender: Any) {
        viewModel?.connectAction()
    }
    
    // MARK: - Private
    private func setupIcon() {
        guard let viewModel = viewModel else { return }
        
        switch viewModel.icon {
        case .image(let name):
            let image = NSImage(named: NSImage.Name(name))
            
            let darkImage = image?.colored(NSColor.protonBlack())
            profileImage.image = darkImage
            
            profileImage.isHidden = false
            profileCircle.isHidden = true
        case .circle(let color):
            profileCircle.profileColor = NSColor(rgbHex: color)
            profileImage.isHidden = true
            profileCircle.isHidden = false
        }
    }
    
    private func setupLabels() {
        guard let viewModel = viewModel else { return }
        
        label.attributedStringValue = viewModel.name
        secondaryLabel.attributedStringValue = viewModel.secondaryDescription
    }
    
    private func setupSeperator() {
        seperator.fillColor = .protonGreySeperatorOnWhite()
    }
    
    private func setupButton() {
        button.stateChanged = { [weak self] in
            guard let `self` = self else { return }
            
            if self.button.isHovered, let viewModel = self.viewModel, viewModel.canConnect {
                self.backgroundColor = .protonGreySeperatorOnWhite()
            } else {
                self.backgroundColor = .protonWhite()
            }
        }
    }
    
    private func setupAvailability() {
        [profileImage, profileCircle, label, secondaryLabel].forEach { view in
            view?.alphaValue = viewModel?.alphaOfMainElements ?? 1
        }
    }
}
