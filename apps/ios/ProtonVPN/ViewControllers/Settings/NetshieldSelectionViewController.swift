//
//  NetshieldSelectionViewController.swift
//  ProtonVPN - Created on 2020-09-09.
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

class NetshieldSelectionViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    private var viewModel: NetshieldSelectionViewModel
    private var genericDataSource: GenericTableViewDataSource?
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(viewModel: NetshieldSelectionViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "NetshieldSelectionViewController", bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupTableView()
        
        viewModel.onDataChange = { [weak self] in
            self?.updateTableView()
            self?.tableView.reloadData()
        }
        viewModel.onFinish = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        tableView.reloadData()
    }
    
    private func setupView() {
        navigationItem.title = LocalizedString.netshieldTitle
        view.backgroundColor = .protonGrey()
        view.layer.backgroundColor = UIColor.protonGrey().cgColor
    }
    
    private func setupTableView() {
        updateTableView()
        
        tableView.separatorColor = .protonBlack()
        tableView.backgroundColor = .protonDarkGrey()
        tableView.cellLayoutMarginsFollowReadableWidth = true
    }
    
    private func updateTableView() {
        genericDataSource = GenericTableViewDataSource(for: tableView, with: viewModel.tableViewData)
        tableView.dataSource = genericDataSource
        tableView.delegate = genericDataSource
    }
    
}
