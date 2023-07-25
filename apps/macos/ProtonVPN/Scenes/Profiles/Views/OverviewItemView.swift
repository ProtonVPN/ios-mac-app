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
import LegacyCommon

class OverviewItemView: NSTableRowView {
    
    @IBOutlet weak var profileImage: NSImageView!
    @IBOutlet weak var profileCircle: ProfileCircle!
    
    @IBOutlet weak var profileNameField: NSTextField!
    @IBOutlet weak var connectionDescriptionField: NSTextField!
    @IBOutlet weak var actionButtonStackView: NSStackView!
    @IBOutlet weak var connectButton: InteractiveActionButton!
    @IBOutlet weak var editButton: InteractiveActionButton!
    @IBOutlet weak var deleteButton: InteractiveActionButton!
    @IBOutlet weak var rowSeparator: NSBox!
    
    fileprivate var viewModel: OverviewItemViewModel!

    private lazy var accessibilityConnectAction: NSAccessibilityCustomAction = {
        let connectActionName = viewModel.isUsersTierTooLow ? LocalizedString.upgrade : LocalizedString.connect
        return NSAccessibilityCustomAction(name: connectActionName, target: self, selector: #selector(connectButtonAction(_:)))
    }()

    private lazy var accessibilityEditAction: NSAccessibilityCustomAction = {
        NSAccessibilityCustomAction(name: LocalizedString.edit, target: self, selector: #selector(editButtonAction(_:)))
    }()

    private lazy var accessibilityDeleteAction: NSAccessibilityCustomAction = {
        NSAccessibilityCustomAction(name: LocalizedString.delete, target: self, selector: #selector(deleteButtonAction(_:)))
    }()
    
    func updateView(withModel viewModel: OverviewItemViewModel) {
        self.viewModel = viewModel
        
        setupImage()
        setupLabels()
        setupButtons()
        setupAvailability()
        setupAccessibilityCustomActions()
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        
        editButton.isHovered = false
        deleteButton.isHovered = false
    }
    
    private func setupImage() {
        switch viewModel.icon {
        case .image:
            profileImage.image = viewModel.icon.icon?.colored()
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

        setupConnectButton(action: accessibilityConnectAction)
        setupEditButton(action: accessibilityEditAction)
        setupDeleteButton(action: accessibilityDeleteAction)

        rowSeparator.fillColor = .color(.border, .weak)
    }

    private func setupConnectButton(action: NSAccessibilityCustomAction) {
        connectButton.title = action.name
        connectButton.fontSize = .heading4
        connectButton.target = action.target
        connectButton.action = action.selector
        (connectButton.cell as! NSButtonCell).imageDimsWhenDisabled = false
        connectButton.isEnabled = viewModel.canConnect
    }

    private func setupEditButton(action: NSAccessibilityCustomAction) {
        editButton.title = action.name
        editButton.fontSize = .heading4
        editButton.isHidden = viewModel.isSystemProfile
        editButton.target = action.target
        editButton.action = action.selector
    }

    private func setupDeleteButton(action: NSAccessibilityCustomAction) {
        deleteButton.title = action.name
        deleteButton.fontSize = .heading4
        deleteButton.isHidden = viewModel.isSystemProfile
        deleteButton.target = action.target
        deleteButton.action = action.selector
    }
    
    private func setupAvailability() {
        [profileImage, profileCircle, profileNameField, connectionDescriptionField].forEach { view in
            view?.alphaValue = viewModel.alphaOfMainElements
        }
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

// MARK: - Accessibility

    override func accessibilityLabel() -> String? {
        return viewModel.name.string
    }

    private func setupAccessibilityCustomActions() {
        var actions = [NSAccessibilityCustomAction]()
        if !viewModel.isSystemProfile {
            actions.append(accessibilityDeleteAction)
            actions.append(accessibilityEditAction)
        }
        if viewModel.canConnect {
            actions.append(accessibilityConnectAction)
        }
        setAccessibilityCustomActions(actions)
    }
}
