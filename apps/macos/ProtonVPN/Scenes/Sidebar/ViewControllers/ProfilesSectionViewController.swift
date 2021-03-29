//
//  ProfilesSectionViewController.swift
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

class ProfileSectionViewController: NSViewController {
    
    fileprivate struct CellIdentifier {
        static let profile = "Profile"
        static let footer = "Footer"
    }
    
    @IBOutlet weak var profileListTableView: NSTableView!
    @IBOutlet weak var profileListScrollView: NSScrollView!
    
    fileprivate let viewModel: ProfilesSectionViewModel
    
    required init?(coder: NSCoder) {
        fatalError("Unsupproted initializer")
    }
    
    required init(viewModel: ProfilesSectionViewModel) {
        self.viewModel = viewModel
        super.init(nibName: NSNib.Name("ProfilesSection"), bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupTableView()
    }
    
    private func setupView() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.protonGrey().cgColor
    }
    
    private func setupTableView() {
        profileListTableView.dataSource = self
        profileListTableView.delegate = self
        profileListTableView.ignoresMultiClick = true
        profileListTableView.selectionHighlightStyle = .none
        profileListTableView.backgroundColor = .protonGrey()
        profileListTableView.register(NSNib(nibNamed: NSNib.Name("ProfileItem"), bundle: nil), forIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifier.profile))
        profileListTableView.register(NSNib(nibNamed: NSNib.Name("FooterItem"), bundle: nil), forIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifier.footer))
        
        profileListScrollView.backgroundColor = .protonGrey()
        
        viewModel.contentChanged = { [unowned self] in self.contentChanged() }
    }
    
    private func contentChanged() {
        let oldIndices = IndexSet(integersIn: 0..<profileListTableView.numberOfRows)
        let newIndices = IndexSet(integersIn: 0..<viewModel.cellCount)
        
        profileListTableView.removeRows(at: oldIndices, withAnimation: [])
        profileListTableView.insertRows(at: newIndices, withAnimation: [])
    }
}

extension ProfileSectionViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return viewModel.cellCount
    }
}

extension ProfileSectionViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return viewModel.cellHeight(forRow: row)
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellModel = viewModel.cellModel(forRow: row)
        
        switch cellModel {
        case .profile(let profileModel):
            let item = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifier.profile), owner: nil) as! ProfileItemView
            item.updateView(withModel: profileModel)
            return item
        case .footer(let footerModel):
            let item = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifier.footer), owner: nil) as! FooterItemView
            item.updateView(withModel: footerModel)
            return item
        }
    }
}
