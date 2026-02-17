//
//  LogSelectionViewController.swift
//  ProtonVPN - Created on 10.08.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import ComposableArchitecture
import LegacyCommon
import Strings
import UIKit

final class LogSelectionViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .plain)

    var genericDataSource: GenericTableViewDataSource?

    @UIBindable private var store: StoreOf<LogSelectionFeature>

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(store: StoreOf<LogSelectionFeature>) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLayout()
        setupView()
        setupTableView()
        observeState()
        setupNavigation()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        tableView.reloadData()
    }

    deinit {
        store.send(.onDisappear)
    }

    private func setupView() {
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

    private func setupNavigation() {
        navigationDestination(item: $store.destination.logs) { logsState in
            let logsStore = Store(
                initialState: logsState,
                reducer: { LogsViewFeature() }
            )
            return LogsViewController(store: logsStore)
        }

        present(item: $store.destination.logsDownloadFailedAlert, id: \.self) { [weak self] message in
            let alert = UIAlertController(title: "Download failed", message: message, preferredStyle: .alert)
            alert.addAction(
                UIAlertAction(title: "OK", style: .default) { _ in
                    self?.store.send(.binding(.set(\.destination, nil)))
                }
            )
            return alert
        }

        present(item: $store.destination.shareLogs, id: \.absoluteString, onDismiss: { [weak self] in
            self?.store.send(.binding(.set(\.destination, nil)))
        }) { [weak self] downloadedFileURL in
            let activityViewController = UIActivityViewController(
                activityItems: [downloadedFileURL],
                applicationActivities: nil
            )
            activityViewController.completionWithItemsHandler = { _, _, _, _ in
                self?.store.send(.binding(.set(\.destination, nil)))
            }
            return activityViewController
        }
    }

    private func updateTableView() {
        let rows = store.rows
        let cells: [TableViewCellModel] = rows.map { row in
            switch row {
            case .logSource:
                return TableViewCellModel.pushStandard(title: row.title) { [weak self] in
                    self?.store.send(.rowTapped(row))
                }
            case .downloadAppleTVLogs:
                let shareImage = UIImage(systemName: "square.and.arrow.up") ?? UIImage()
                return TableViewCellModel.imageSubtitleImage(
                    title: row.title,
                    trailingImage: shareImage
                ) { [weak self] in
                    self?.store.send(.rowTapped(row))
                }
            }
        }
        let sections = [TableViewSection(title: "", showHeader: false, cells: cells)]
        genericDataSource = GenericTableViewDataSource(for: tableView, with: sections)
        tableView.dataSource = genericDataSource
        tableView.delegate = genericDataSource
    }

    private func observeState() {
        observe { [weak self] in
            guard let self else { return }

            navigationItem.title = store.title
            updateTableView()
        }
    }
}
