//
//  OverviewViewController.swift
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

class OverviewViewController: NSViewController {
    
    fileprivate let overviewItemIdentifier = "OverviewItemCell"

    @IBOutlet weak var profileLabel: PVPNTextField!
    @IBOutlet weak var connectionLabel: PVPNTextField!
    @IBOutlet weak var actionLabel: PVPNTextField!
    @IBOutlet weak var profileListTableView: NSTableView!
    @IBOutlet weak var profileListScrollView: NSScrollView!
    @IBOutlet weak var footerView: NSView!
    @IBOutlet weak var createNewProfileButton: PrimaryActionButton!

    fileprivate var viewModel: OverviewViewModel!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    required init(viewModel: OverviewViewModel) {
        super.init(nibName: NSNib.Name("Overview"), bundle: nil)
        self.viewModel = viewModel
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupHeaderView()
        setupTableView()
        setupFooterView()
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        
        createNewProfileButton.isHovered = false
    }
    
    private func setupView() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.protonGrey().cgColor
    }
    
    private func setupHeaderView() {
        profileLabel.attributedStringValue = LocalizedString.profile.uppercased().attributed(withColor: .protonGreyOutOfFocus(), fontSize: 12, bold: true, alignment: .left)
        connectionLabel.attributedStringValue = LocalizedString.connection.uppercased().attributed(withColor: .protonGreyOutOfFocus(), fontSize: 12, bold: true, alignment: .left)
        actionLabel.attributedStringValue = LocalizedString.action.uppercased().attributed(withColor: .protonGreyOutOfFocus(), fontSize: 12, bold: true, alignment: .left)
    }
    
    private func setupTableView() {
        profileListTableView.dataSource = self
        profileListTableView.delegate = self
        profileListTableView.ignoresMultiClick = true
        profileListTableView.selectionHighlightStyle = .none
        profileListTableView.backgroundColor = .protonGrey()
        profileListTableView.register(NSNib(nibNamed: NSNib.Name("OverviewItem"), bundle: nil), forIdentifier: NSUserInterfaceItemIdentifier(rawValue: overviewItemIdentifier))
        
        profileListScrollView.backgroundColor = .protonGrey()
        
        viewModel.contentChanged = { [unowned self] in self.contentChanged() }
    }
    
    private func setupFooterView() {
        footerView.wantsLayer = true
        footerView.layer?.backgroundColor = NSColor.protonGreyShade().cgColor
        
        createNewProfileButton.title = LocalizedString.createNewProfile
        createNewProfileButton.target = self
        createNewProfileButton.action = #selector(createNewProfileButtonAction)
    }
    
    private func contentChanged() {
        let oldIndices = IndexSet(integersIn: 0..<profileListTableView.numberOfRows)
        let newIndices = IndexSet(integersIn: 0..<viewModel.cellCount)
        
        profileListTableView.removeRows(at: oldIndices, withAnimation: [])
        profileListTableView.insertRows(at: newIndices, withAnimation: [])
    }
    
    @objc private func createNewProfileButtonAction() {
        viewModel.createNewProfileAction()
    }
}

extension OverviewViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return viewModel.cellCount
    }
}

extension OverviewViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return viewModel.cellHeight
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let rowItem = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: overviewItemIdentifier), owner: nil) as! OverviewItemView
        let cellViewModel = viewModel.cellModel(forIndex: row)
        cellViewModel.delegate = self
        rowItem.updateView(withModel: cellViewModel)
        return rowItem
    }
}

extension OverviewViewController: OverviewItemViewModelDelegate {
    
    func showDeleteWarning(_ viewModel: WarningPopupViewModel) {
        presentAsModalWindow(WarningPopupViewController(viewModel: viewModel))
    }
}
