//
//  LogSelectionViewController.swift
//  ProtonVPN - Created on 10.08.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import LegacyCommon
import Strings
import UIKit

class LogSelectionViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .plain)

    var genericDataSource: GenericTableViewDataSource?

    private let viewModel: LogSelectionViewModel
    private let settingsService: SettingsService
    private let appleTVLogsDownloader: AppleTVLogsDownloading

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(
        viewModel: LogSelectionViewModel,
        settingsService: SettingsService,
        appleTVLogsDownloader: AppleTVLogsDownloading = AppleTVLogsDownloadService()
    ) {
        self.viewModel = viewModel
        self.settingsService = settingsService
        self.appleTVLogsDownloader = appleTVLogsDownloader

        super.init(nibName: nil, bundle: nil)

        viewModel.pushHandler = { [weak self] logSource in
            self?.pushViewController(settingsService.makeLogsViewController(logSource: logSource))
        }
        viewModel.downloadAppleTVLogsHandler = { [weak self] in
            self?.downloadLogsFromAppleTV()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLayout()
        setupView()
        setupTableView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        tableView.reloadData()
    }

    deinit {
        appleTVLogsDownloader.cancel()
    }

    private func setupView() {
        navigationItem.title = Localizable.logs
        view.backgroundColor = .backgroundColor()
        view.layer.backgroundColor = UIColor.backgroundColor().cgColor
    }

    private func setupLayout() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
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

    private func downloadLogsFromAppleTV() {
        appleTVLogsDownloader.downloadLogs { [weak self] result in
            guard let self else { return }
            switch result {
            case let .success(downloadedFileURL):
                let presentShare = {
                    let activityViewController = UIActivityViewController(
                        activityItems: [downloadedFileURL],
                        applicationActivities: nil
                    )
                    self.navigationController?.present(activityViewController, animated: true)
                }
                if Thread.isMainThread {
                    presentShare()
                } else {
                    DispatchQueue.main.async(execute: presentShare)
                }
            case let .failure(error):
                presentAlert(title: "Download failed", message: error.localizedDescription)
            }
        }
    }

    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
