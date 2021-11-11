//
//  SecureDNSViewController.swift
//  ProtonVPN
//
//  Created by Jack Kim-Biggs on 11/4/21.
//  Copyright © 2021 Jack Kim-Biggs. All rights reserved.
//

import Foundation

import UIKit
import vpncore

final class SecureDNSViewController: UIViewController {

    @IBOutlet private weak var tableView: UITableView!

    private var genericDataSource: GenericTableViewDataSource?

    private let viewModel: SecureDNSViewModel

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(viewModel: SecureDNSViewModel) {
        self.viewModel = viewModel

        super.init(nibName: "SecureDNS", bundle: nil)

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
        navigationItem.title = LocalizedString.secureDnsProtocol
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
