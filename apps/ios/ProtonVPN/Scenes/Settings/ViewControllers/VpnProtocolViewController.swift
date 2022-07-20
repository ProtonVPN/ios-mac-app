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

final class VpnProtocolViewController: UIViewController {

    @IBOutlet private weak var tableView: UITableView!
    
    private var genericDataSource: GenericTableViewDataSource?
    
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
        viewModel.selectionFinished = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
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
        view.backgroundColor = .backgroundColor()
        view.layer.backgroundColor = UIColor.backgroundColor().cgColor
    }
    
    private func setupTableView() {
        updateTableView()
        
        tableView.separatorColor = .normalSeparatorColor()
        tableView.backgroundColor = .backgroundColor()
        tableView.cellLayoutMarginsFollowReadableWidth = true
    }
    
    private func updateTableView() {
        genericDataSource = GenericTableViewDataSource(for: tableView, with: viewModel.tableViewData)
        tableView.dataSource = genericDataSource
        tableView.delegate = genericDataSource
    }

}
