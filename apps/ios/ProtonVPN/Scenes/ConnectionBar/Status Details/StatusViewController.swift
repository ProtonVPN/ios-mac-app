//
//  StatusViewController.swift
//  ProtonVPN - Created on 01.07.19.
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

import GSMessages
import UIKit
import LegacyCommon
import Strings

final class StatusViewController: UIViewController {
    @IBOutlet private weak var tableView: UITableView?
    
    var viewModel: StatusViewModel? {
        didSet {
            viewModel?.messageHandler = { [weak self] text, type, options in
                self?.showMessage(text, type: type, options: options)
            }
            viewModel?.contentChanged = { [weak self] in
                self?.updateTableView()
                self?.tableView?.reloadData()
            }
            viewModel?.rowsUpdated = { [weak self] rows in
                guard let genericDataSource = self?.genericDataSource else { return }
                genericDataSource.update(rows: rows)
                self?.tableView?.reloadRows(at: Array(rows.keys), with: .none)
            }
            viewModel?.pushHandler = { [weak self] viewController in
                self?.pushViewController(viewController)
            }
        }
    }
    
    private var genericDataSource: GenericTableViewDataSource?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupTableView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        tableView?.reloadData()
    }
    
    func setupView() {
        navigationItem.title = Localizable.status
        
        view.backgroundColor = .backgroundColor()
    }
    
    private func setupTableView() {
        updateTableView()
        
        tableView?.separatorColor = .normalSeparatorColor()
        tableView?.backgroundColor = UIColor.backgroundColor()
        tableView?.cellLayoutMarginsFollowReadableWidth = true
    }
    
    private func updateTableView() {
        guard let viewModel = viewModel, let tableView = tableView else {
            return
        }
        
        genericDataSource = GenericTableViewDataSource(for: tableView, with: viewModel.tableViewData)
        tableView.dataSource = genericDataSource
        tableView.delegate = genericDataSource
    }

    private func pushViewController(_ viewController: UIViewController) {
        navigationController?.pushViewController(viewController, animated: true)
    }
}
