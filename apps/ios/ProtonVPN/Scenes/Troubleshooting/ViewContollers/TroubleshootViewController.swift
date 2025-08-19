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

import Ergonomics
import LegacyCommon
import ProtonCoreUIFoundations
import Strings
import UIKit

final class TroubleshootViewController: UIViewController {
    private var headerView: UIView = .init().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.backgroundColor = .secondaryBackgroundColor()
    }

    private var titleLabel: UILabel = .init().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.textAlignment = .center
        $0.lineBreakMode = .byTruncatingTail
        $0.attributedText = Localizable.troubleshootTitle.attributed(withColor: .normalTextColor(), fontSize: 24)
    }

    private lazy var closeButton: UIButton = .init(type: .custom).with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.setImage(IconProvider.crossBig, for: .normal)
        $0.tintColor = .normalTextColor()
        $0.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
    }

    private lazy var tableView: UITableView = .init().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.backgroundColor = .backgroundColor()
        $0.rowHeight = UITableView.automaticDimension
        $0.estimatedRowHeight = 80.0
        $0.alwaysBounceVertical = true
        $0.register(TroubleshootingCell.self, forCellReuseIdentifier: TroubleshootingCell.cellIdentifier)
        $0.register(TroubleshootingSwitchCell.self, forCellReuseIdentifier: TroubleshootingSwitchCell.switchCellId)
        $0.dataSource = self
    }

    public var viewModel: TroubleshootViewModel

    // MARK: - Init

    init(_ viewModel: TroubleshootViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        setupConstraints()
    }

    // MARK: - Setup

    private func setupViews() {
        // Configure main view
        view.backgroundColor = .backgroundColor()

        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(closeButton)

        view.addSubview(tableView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Header view constraints
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 60),

            // Title label constraints
            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),

            // Close button constraints
            closeButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            closeButton.topAnchor.constraint(equalTo: headerView.topAnchor),
            closeButton.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 60),
            closeButton.heightAnchor.constraint(equalToConstant: 60),

            // Table view constraints
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: User actions

    @objc
    func closeButtonTapped() {
        viewModel.cancel()
    }
}

// MARK: TableView

extension TroubleshootViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModel.items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = viewModel.items[indexPath.row]

        var cell: TroubleshootingCell
        if let actionable = item as? ActionableTroubleshootItem {
            guard let tempCell = tableView.dequeueReusableCell(withIdentifier: TroubleshootingSwitchCell.switchCellId) as? TroubleshootingSwitchCell else {
                return UITableViewCell()
            }
            tempCell.isOn = actionable.isOn
            tempCell.isOnChanged = { isOn in
                actionable.set(isOn: isOn)
            }
            cell = tempCell
        } else {
            guard let tempCell = tableView.dequeueReusableCell(withIdentifier: TroubleshootingCell.cellIdentifier) as? TroubleshootingCell else {
                return UITableViewCell()
            }
            cell = tempCell
        }
        cell.title = item.title
        cell.descriptionAttributed = item.description
        return cell
    }
}
