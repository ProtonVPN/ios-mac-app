//
//  StatusMenuProfilesListController.swift
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

class StatusMenuProfilesListController: WindowController {

    fileprivate let statusMenuProfileItemIdentifier = "StatusMenuProfileItemCell"
    
    @IBOutlet weak var topView: NSView!
    @IBOutlet weak var roundedView: NSView!
    @IBOutlet weak var profileList: NSTableView!
    
    var viewModel: StatusMenuProfilesListViewModel
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    init(windowNibName nibName: NSNib.Name, viewModel: StatusMenuProfilesListViewModel) {
        self.viewModel = viewModel
        
        super.init(window: nil)
        
        Bundle.main.loadNibNamed(nibName, owner: self, topLevelObjects: nil)
        
        setupWindow()
        setupProfilesList()
        monitorsKeyEvents = true
    }
    
    private func setupWindow() {
        guard let window = window else { return }
        
        window.styleMask = .borderless
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.hasShadow = false
        
        window.ignoresMouseEvents = false
        
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = .clear
        
        topView.wantsLayer = true
        topView.layer?.backgroundColor = NSColor.protonWhite().cgColor
        
        roundedView.wantsLayer = true
        roundedView.layer?.backgroundColor = NSColor.protonWhite().cgColor
        roundedView.layer?.cornerRadius = 8
    }
    
    private func setupProfilesList() {
        profileList.dataSource = self
        profileList.delegate = self
        profileList.ignoresMultiClick = true
        profileList.selectionHighlightStyle = .none
        profileList.backgroundColor = .clear
        profileList.register(NSNib(nibNamed: NSNib.Name("StatusMenuProfileViewItem"), bundle: nil), forIdentifier: NSUserInterfaceItemIdentifier(rawValue: statusMenuProfileItemIdentifier))
    }
}

extension StatusMenuProfilesListController: NSTableViewDelegate {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return viewModel.cellCount
    }
}

extension StatusMenuProfilesListController: NSTableViewDataSource {
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return viewModel.cellHeight
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let rowItem = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: statusMenuProfileItemIdentifier), owner: nil) as! StatusMenuProfileViewItem
        let cellViewModel = viewModel.cellModel(forIndex: row)
        rowItem.updateView(withModel: cellViewModel)
        return rowItem
    }
}
