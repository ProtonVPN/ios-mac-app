//
//  HelpPopoverViewController.swift
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
import Strings

class HelpPopoverViewController: NSViewController {

    private let viewModel: HelpPopoverViewModel
    
    @IBOutlet private weak var resetButton: InteractiveActionButton!
    @IBOutlet private weak var forgotButton: InteractiveActionButton!
    @IBOutlet private weak var commonIssuesButton: InteractiveActionButton!
    @IBOutlet private weak var reportBugButton: InteractiveActionButton!
    
    required init(viewModel: HelpPopoverViewModel) {
        self.viewModel = viewModel
        
        super.init(nibName: NSNib.Name("HelpPopover"), bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        resetButton.title = Localizable.resetPassword
        forgotButton.title = Localizable.forgotUsername
        commonIssuesButton.title = Localizable.commonIssues
        reportBugButton.title = Localizable.reportBug
    }
    
    @IBAction func resetAction(_ sender: Any) {
        viewModel.resetAction()
    }

    @IBAction func forgotAction(_ sender: Any) {
        viewModel.forgotAction()
    }

    @IBAction func commonIssuesAction(_ sender: Any) {
        viewModel.commonIssuesAction()
    }

    @IBAction func reportBugAction(_ sender: Any) {
        viewModel.reportBugAction()
    }
}
