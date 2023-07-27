//
//  LogSelectionViewController.swift
//  ProtonVPN - Created on 10.08.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import UIKit
import LegacyCommon
import Strings

class LogSelectionViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    var genericDataSource: GenericTableViewDataSource?
    
    private let viewModel: LogSelectionViewModel
    private let settingsService: SettingsService
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(viewModel: LogSelectionViewModel, settingsService: SettingsService) {
        self.viewModel = viewModel
        self.settingsService = settingsService

        super.init(nibName: "LogSelection", bundle: nil)
        
        viewModel.pushHandler = { [weak self] logSource in
            self?.pushViewController(settingsService.makeLogsViewController(logSource: logSource))
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
        navigationItem.title = Localizable.logs
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
    
    private func pushViewController(_ viewController: UIViewController) {
        navigationController?.pushViewController(viewController, animated: true)
    }
}
