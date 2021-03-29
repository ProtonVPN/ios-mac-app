//
//  OverviewItemView.swift
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
import vpncore

class OverviewItemView: NSTableRowView {
    
    @IBOutlet weak var profileImage: NSImageView!
    @IBOutlet weak var profileCircle: ProfileCircle!
    
    @IBOutlet weak var profileNameField: NSTextField!
    @IBOutlet weak var connectionDescriptionField: NSTextField!
    @IBOutlet weak var actionButtonStackView: NSStackView!
    @IBOutlet weak var connectButton: GreenActionButton!
    @IBOutlet weak var editButton: GreenActionButton!
    @IBOutlet weak var deleteButton: GreenActionButton!
    @IBOutlet weak var rowSeparator: NSBox!
    
    fileprivate var viewModel: OverviewItemViewModel!
    
    func updateView(withModel viewModel: OverviewItemViewModel) {
        self.viewModel = viewModel
        
        setupImage()
        setupLabels()
        setupButtons()
        setupAvailability()
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        
        editButton.isHovered = false
        deleteButton.isHovered = false
    }
    
    private func setupImage() {
        switch viewModel.icon {
        case .image(let name):
            profileImage.image = NSImage(named: NSImage.Name(name))
            profileImage.isHidden = false
            profileCircle.isHidden = true
        case .circle(let color):
            profileCircle.profileColor = NSColor(rgbHex: color)
            profileImage.isHidden = true
            profileCircle.isHidden = false
        }
    }
    
    private func setupLabels() {
        profileNameField.attributedStringValue = viewModel.name
        connectionDescriptionField.attributedStringValue = viewModel.description
    }
    
    private func setupButtons() {
        actionButtonStackView.distribution = viewModel.isSystemProfile ? .gravityAreas : .equalSpacing
        
        connectButton.title = viewModel.connectButtonTitle
        connectButton.fontSize = 16.0
        connectButton.target = self
        connectButton.action = #selector(connectButtonAction(_:))
        (connectButton.cell as! NSButtonCell).imageDimsWhenDisabled = false
        connectButton.isEnabled = viewModel.canConnect
        
        editButton.title = LocalizedString.edit
        editButton.fontSize = 16.0
        editButton.isHidden = viewModel.isSystemProfile
        editButton.target = self
        editButton.action = #selector(editButtonAction(_:))
        
        deleteButton.title = LocalizedString.delete
        deleteButton.fontSize = 16.0
        deleteButton.isHidden = viewModel.isSystemProfile
        deleteButton.target = self
        deleteButton.action = #selector(deleteButtonAction(_:))
        
        rowSeparator.fillColor = NSColor.protonLightGrey()
    }
    
    private func setupAvailability() {
        [profileImage, profileCircle, profileNameField, connectionDescriptionField].forEach { view in
            view?.alphaValue = viewModel.alphaOfMainElements
        }
        connectButton.title = viewModel.isUsersTierTooLow ? LocalizedString.upgrade : LocalizedString.connect
    }
    
    @objc private func connectButtonAction(_ sender: Any) {
        viewModel.connectAction {
            window?.close()
        }
    }
    
    @objc private func editButtonAction(_ sender: Any) {
        viewModel.editAction()
    }
    
    @objc private func deleteButtonAction(_ sender: Any) {
        viewModel.deleteAction()
    }
}
