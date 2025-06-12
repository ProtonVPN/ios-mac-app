//
//  CountriesViewController.swift
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

import UIKit

import Dependencies

import ProtonCoreUIFoundations
import ProtonCoreFeatureFlags

import CommonNetworking
import LegacyCommon
import Announcement
import Search

import Strings
import Domain

final class CountriesViewController: UIViewController {
    @IBOutlet private weak var connectionBarContainerView: UIView!
    @IBOutlet private weak var secureCoreSeparator: UIView!
    @IBOutlet private weak var secureCoreSeparatorHeight: NSLayoutConstraint!
    @IBOutlet private weak var secureCoreBar: UIView!
    @IBOutlet private weak var secureCoreLabel: UILabel!
    @IBOutlet private weak var secureCoreSwitch: ConfirmationToggleSwitch!
    @IBOutlet private weak var tableView: UITableView!

    var viewModel: CountriesViewModel!
    var connectionBarViewController: ConnectionBarViewController?

    var coordinator: SearchCoordinator?

    override func awakeFromNib() {
        super.awakeFromNib()
        if FeatureFlagsRepository.isRedesigniOSEnabled {
            tabBarItem = UITabBarItem(title: Localizable.countries, image: IconProvider.earth, tag: 1)
        } else {
            tabBarItem = UITabBarItem(title: Localizable.countries, image: IconProvider.earth, tag: 0)
        }

        tabBarItem.accessibilityIdentifier = "Countries"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.delegate = self
        setupView()
        if FeatureFlagsRepository.isRedesigniOSEnabled {
            connectionBarContainerView.removeFromSuperview()
        } else {
            setupConnectionBar()
        }
        setupSecureCoreBar()
        setupTableView()
        setupNavigationBar()

        AppEvent.announcementStorageContent.subscribe(self, selector: #selector(setupAnnouncements))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !FeatureFlagsRepository.isRedesigniOSEnabled {
            setupAnnouncements()
        }
    }

    private func setupView() {
        navigationItem.title = Localizable.countries
        view.layer.backgroundColor = UIColor.backgroundColor().cgColor
    }

    private func setupConnectionBar() {
        if let connectionBarViewController = connectionBarViewController {
            connectionBarViewController.embed(in: self, with: connectionBarContainerView)
        }
    }

    private func setupSecureCoreBar() {
        secureCoreSeparator.backgroundColor = .normalSeparatorColor()
        secureCoreSeparatorHeight.constant = 1 / UIScreen.main.scale
        secureCoreBar.backgroundColor = .backgroundColor()
        secureCoreLabel.textColor = .normalTextColor()
        secureCoreLabel.text = Localizable.useSecureCore
        secureCoreSwitch.accessibilityIdentifier = "secureCoreSwitch"
        if let viewModel = viewModel {
            secureCoreSwitch.isEnabled = viewModel.enableViewToggle
            secureCoreSwitch.isOn = viewModel.secureCoreOn
        }
        secureCoreSwitch.tapped = { [weak self] in
            let toOn = self?.viewModel?.secureCoreOn == true
            self?.viewModel?.toggleState(toOn: !toOn) { [weak self] succeeded in
                DispatchQueue.main.async {
                    guard let self = self else {
                        return
                    }

                    self.secureCoreSwitch.setOn(self.viewModel.secureCoreOn, animated: true)

                    if succeeded {
                        self.tableView.reloadData()
                    }
                }
            }
        }
    }

    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.cellLayoutMarginsFollowReadableWidth = true
        tableView.rowHeight = UITableView.automaticDimension
        tableView.backgroundColor = .backgroundColor()
        tableView.register(CountryCell.nib, forCellReuseIdentifier: CountryCell.identifier)
        tableView.register(ServersHeaderView.nib, forHeaderFooterViewReuseIdentifier: ServersHeaderView.identifier)
        tableView.register(DefaultProfileTableViewCell.nib, forCellReuseIdentifier: DefaultProfileTableViewCell.identifier)
        tableView.register(BannerViewCell.nib, forCellReuseIdentifier: BannerViewCell.identifier)
        tableView.register(OfferBannerViewCell.nib, forCellReuseIdentifier: OfferBannerViewCell.identifier)
    }

    private func setupNavigationBar() {
        let infoButton = UIBarButtonItem(image: IconProvider.infoCircle, style: .plain, target: self, action: #selector(displayServicesInfo))
        let searchButton = UIBarButtonItem(image: IconProvider.magnifier, style: .plain, target: self, action: #selector(showSearch))
        searchButton.accessibilityIdentifier = "countrySearchButton"
        navigationItem.rightBarButtonItems = [searchButton, infoButton]
    }

    @objc private func displayServicesInfo() {
        let viewModel = ServersFeaturesInformationViewModelImplementation.servicesInfo
        let vc = ServersFeaturesInformationVC(viewModel)
        vc.modalPresentationStyle = .overFullScreen
        present(vc, animated: true, completion: nil)
    }

    private func contentChanged() {
        guard let viewModel = viewModel else { return }
        secureCoreSwitch.setOn(viewModel.secureCoreOn, animated: true)
        tableView.reloadData()
    }

    func showCountry(cellModel: CountryItemViewModel) {
        if cellModel.isUsersTierTooLow {
            viewModel.presentUpsell(forCountryCode: cellModel.countryCode)
            return
        }

        guard let countryViewController = viewModel.countryViewController(viewModel: cellModel) else {
            return
        }

        self.navigationController?.pushViewController(countryViewController, animated: true)
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate

extension CountriesViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections()
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if viewModel.numberOfSections() < 2 {
            return nil
        }

        guard let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: ServersHeaderView.identifier) as? ServersHeaderView else {
            return nil
        }

        headerView.setName(name: viewModel.titleFor(section: section) ?? "")
        headerView.callback = viewModel.callback(forSection: section)

        return headerView
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return viewModel.headerHeight(for: section)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRows(in: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellModel = viewModel.cellModel(for: indexPath.row, in: indexPath.section)
        switch cellModel {
        case let .serverGroup(viewModel):
            guard let countryCell = tableView.dequeueReusableCell(withIdentifier: CountryCell.identifier) as? CountryCell else {
                return UITableViewCell()
            }
            countryCell.viewModel = viewModel
            return countryCell

        case let .profile(viewModel):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: DefaultProfileTableViewCell.identifier) as? DefaultProfileTableViewCell else {
                return UITableViewCell()
            }
            cell.viewModel = viewModel
            return cell

        case let .banner(viewModel):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: BannerViewCell.identifier) as? BannerViewCell else {
                return UITableViewCell()
            }
            cell.viewModel = viewModel
            return cell

        case let .offerBanner(viewModel):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: OfferBannerViewCell.identifier) as? OfferBannerViewCell else {
                return UITableViewCell()
            }
            cell.viewModel = viewModel
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cellModel = viewModel.cellModel(for: indexPath.row, in: indexPath.section)
        switch cellModel {
        case let .serverGroup(viewModel):
            showCountry(cellModel: viewModel)

        case .profile:
            // Default profile cell used atm intercepts clicks and handles them inside `DefaultProfileViewModel`.
            break

        case let .banner(viewModel):
            viewModel.action()

        case let .offerBanner(viewModel):
            @Dependency(\.sessionService) var sessionService
            Task {
                await viewModel.action(sessionService)
            }
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.1
    }
}

// MARK: - CountriesVMDelegate

extension CountriesViewController: CountriesVMDelegate {
    func onContentChange() {
        contentChanged()
        reloadSearch()
    }

    func displayFastestConnectionInfo() {}

    func displayGatewayInfo() {
        let viewModel = ServersFeaturesInformationViewModelImplementation.gatewaysInfo
        let vc = ServersFeaturesInformationVC(viewModel)
        vc.modalPresentationStyle = .overFullScreen
        present(vc, animated: true, completion: nil)
    }
}
