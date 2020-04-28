//
//  TroubleshootViewController.swift
//  ProtonVPN - Created on 2020-04-23.
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

import UIKit
import vpncore

class TroubleshootViewController: UIViewController {

    // Views
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var headerView: UIView!
    
    // Data
    public var viewModel: TroubleshootViewModel!
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(_ viewModel: TroubleshootViewModel) {
        super.init(nibName: "TroubleshootViewController", bundle: nil)
        self.viewModel = viewModel
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupView()
    }
    
    private func setupTableView() {
        tableView.register(TroubleshootingCell.nib, forCellReuseIdentifier: TroubleshootingCell.identifier)
        tableView.register(TroubleshootingSwitchCell.nib, forCellReuseIdentifier: TroubleshootingSwitchCell.identifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44.0
        tableView.dataSource = self
    }
    
    private func setupView() {
        view.backgroundColor = .protonGrey()
        tableView.backgroundColor = .protonGrey()
        
        headerView.backgroundColor = .protonLightGrey()
        titleLabel.attributedText = LocalizedString.troubleshootTitle.attributed(withColor: .protonWhite(), fontSize: 24)
        closeButton.setImage(closeButton.imageView?.image?.withRenderingMode(.alwaysTemplate), for: .normal)
        closeButton.tintColor = .protonWhite()
    }
    
    // MARK: User actions
    
    @IBAction func closeButtonTapped(_ sender: Any) {
        viewModel.cancel()
    }

}

// MARK: TableView

extension TroubleshootViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = viewModel.items[indexPath.row]
        
        var cell: TroubleshootingCell
        if item.hasSwitch {
            guard let tempCell = tableView.dequeueReusableCell(withIdentifier: TroubleshootingSwitchCell.identifier) as? TroubleshootingSwitchCell else {
                return UITableViewCell()
            }
            cell = tempCell
        } else {
            guard let tempCell = tableView.dequeueReusableCell(withIdentifier: TroubleshootingCell.identifier) as? TroubleshootingCell else {
                return UITableViewCell()
            }
            cell = tempCell
        }
        cell.title = item.title
        cell.descriptionAttributed = item.description
        return cell
    }
    
}
