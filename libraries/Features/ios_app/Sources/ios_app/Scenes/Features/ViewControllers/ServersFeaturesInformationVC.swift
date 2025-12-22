//
//  ServersFeaturesInformationVC.swift
//  ProtonVPN - Created on 21.04.21.
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

import LegacyCommon
import ProtonCoreUIFoundations
import Strings
import UIKit

class ServersFeaturesInformationVC: UIViewController {
    private let titleLbl: UILabel = {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 17)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = .clear
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let closeButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 3, leading: 3, bottom: 3, trailing: 3)
        config.baseForegroundColor = .white

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let featuresTableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.tintColor = .clear
        tableView.separatorColor = .clear
        tableView.sectionIndexColor = .clear
        tableView.sectionIndexBackgroundColor = .clear
        tableView.sectionIndexTrackingBackgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    let viewModel: ServersFeaturesInformationViewModel

    init(_ viewModel: ServersFeaturesInformationViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - ViewCycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupConstraints()
        configureViews()
    }

    private func setupViews() {
        view.backgroundColor = .backgroundColor()

        view.addSubview(titleLbl)
        view.addSubview(closeButton)
        view.addSubview(featuresTableView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Title label
            titleLbl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Dimensions.titleTop),
            titleLbl.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            titleLbl.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            titleLbl.heightAnchor.constraint(equalToConstant: Dimensions.titleHeight),

            // Close button
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Dimensions.CloseButton.leading),
            closeButton.centerYAnchor.constraint(equalTo: titleLbl.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: Dimensions.CloseButton.size),
            closeButton.heightAnchor.constraint(equalToConstant: Dimensions.CloseButton.size),

            // Features table view
            featuresTableView.topAnchor.constraint(equalTo: titleLbl.bottomAnchor),
            featuresTableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            featuresTableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            featuresTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func configureViews() {
        titleLbl.text = Localizable.informationTitle
        closeButton.setImage(IconProvider.crossBig, for: .normal)
        closeButton.addTarget(self, action: #selector(didTapDismiss), for: .touchUpInside)

        featuresTableView.register(FeatureTableViewCell.self, forCellReuseIdentifier: FeatureTableViewCell.identifier)
        featuresTableView.dataSource = self
        featuresTableView.delegate = self
    }

    // MARK: - Actions

    @objc
    private func didTapDismiss() {
        dismiss(animated: true, completion: nil)
    }
}

extension ServersFeaturesInformationVC: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        viewModel.totalFeatures
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.featuresCount(for: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FeatureTableViewCell.identifier, for: indexPath) as! FeatureTableViewCell
        cell.viewModel = viewModel.getFeatureViewModel(indexPath: indexPath)
        return cell
    }
}

extension ServersFeaturesInformationVC: UITableViewDelegate {
    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        viewModel.headerHeight
    }

    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = ServersHeaderView(reuseIdentifier: nil)
        headerView.setName(name: viewModel.titleFor(section))
        headerView.setColor(color: .backgroundColor())
        return headerView
    }
}

extension ServersFeaturesInformationVC {
    private enum Dimensions {
        static let titleTop: CGFloat = 8
        static let titleHeight: CGFloat = 44

        enum CloseButton {
            static let leading: CGFloat = 12
            static let size: CGFloat = 24
        }
    }
}
