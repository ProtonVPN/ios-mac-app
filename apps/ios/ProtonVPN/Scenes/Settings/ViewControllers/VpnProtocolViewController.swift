//
//  VpnProtocolViewController.swift
//  ProtonVPN - Created on 12.08.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import UIKit
import vpncore

class VpnProtocolViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    var genericDataSource: GenericTableViewDataSource?
    
    private let viewModel: VpnProtocolViewModel
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(viewModel: VpnProtocolViewModel) {
        self.viewModel = viewModel
        
        super.init(nibName: "VpnProtocol", bundle: nil)
        
        viewModel.contentChanged = { [weak self] in
            self?.updateTableView()
            self?.tableView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupTableView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        tableView.reloadData()
    }
    
    private func setupView() {
        navigationItem.title = LocalizedString.vpnProtocol
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
