//
//  AttachedFileView.swift
//  ProtonVPN - Created on 08/07/2019.
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

class AttachedFileView: NSView {
    
    @IBOutlet weak var profileNameLabel: NSTextField!
    @IBOutlet weak var finderButton: NSButton!
    @IBOutlet weak var deleteButton: NSButton!
    @IBOutlet weak var fileImageView: NSImageView!

    private var viewModel: AttachmentRowViewModel!
    
    func updateView(viewModel: AttachmentRowViewModel) {
        self.viewModel = viewModel
        
        profileNameLabel.stringValue = viewModel.url.lastPathComponent
        
        finderButton.target = self
        finderButton.action = #selector(finderButtonPressed)
        
        deleteButton.target = self
        deleteButton.action = #selector(deleteButtonPressed)
    }
    
    // MARK: - Button actions
    
    @objc func finderButtonPressed() {
        NSWorkspace.shared.activateFileViewerSelecting([viewModel.url])
    }
    
    @objc func deleteButtonPressed() {
        viewModel.remove()
    }
    
}
