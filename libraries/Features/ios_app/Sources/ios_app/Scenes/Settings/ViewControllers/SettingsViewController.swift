//
//  SettingsViewController.swift
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

import Announcement
import Combine
import Dependencies
import Domain
import Ergonomics
import LegacyCommon
import ProtonCoreFeatureFlags
import ProtonCoreUIFoundations
import SDWebImage
import Settings
import Sharing
import Strings
import Theme
import UIKit

final class SettingsViewController: UIViewController {
    private var tableView: UITableView = .init().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.separatorColor = .normalSeparatorColor()
        $0.separatorInset = .zero
        $0.backgroundColor = .backgroundColor()
        $0.cellLayoutMarginsFollowReadableWidth = true
        $0.contentInset.bottom = UIConstants.cellHeight
    }

    var genericDataSource: GenericTableViewDataSource?

    private let viewModel: SettingsViewModel

    @Dependency(\.announcementManager) private var announcementManager
    private var announcementsCancellable: AnyCancellable?

    // MARK: - Init

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        self.viewModel.showModalController = { [weak self] viewController in
            executeOnUIThread {
                self?.navigationController?.topViewController?.present(viewController, animated: true)
            }
        }
        self.viewModel.pushHandler = { [weak self] viewController, translucent, hidesBackButton in
            executeOnUIThread {
                self?.pushViewController(viewController, translucentNavBar: translucent, hidesBackButton: hidesBackButton)
            }
        }
        self.viewModel.reloadNeeded = { [weak self] in
            guard let self, isViewLoaded else {
                return
            }

            setupTableView()
            tableView.reloadData()
        }
        @SharedReader(.captureSession) var captureSession

        observe { [weak self] in
            guard let self else { return }
            switch captureSession {
            case .sessionStarted:
                guard recordingTabBarItem != tabBarItem else { return }
                tabBarItem = recordingTabBarItem
            default:
                guard idleTabBarItem != tabBarItem else { return }
                tabBarItem = idleTabBarItem
            }
        }
        tabBarItem.accessibilityIdentifier = "Settings back btn"
    }

    private let recordingTabBarItem = UITabBarItem(
        title: Localizable.settings,
        image: UIImage(resource: .settingsTabbarDot).withRenderingMode(.alwaysOriginal),
        selectedImage: UIImage(resource: .settingsTabbarDotActive).withRenderingMode(.alwaysOriginal)
    )

    private let idleTabBarItem = UITabBarItem(
        title: Localizable.settings,
        image: UIImage(resource: .settingsTabbar).withRenderingMode(.alwaysOriginal),
        selectedImage: UIImage(resource: .settingsTabbarActive).withRenderingMode(.alwaysOriginal)
    )

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()

        setupAnnouncements()
        announcementsCancellable = announcementManager.announcementsPublisher()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.setupAnnouncements() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setupTableView()
        tableView.reloadData()

        /// This is required by QR Login. One of the views in the QR Login flow hides the navigation bar and we need to make sure it is visible when we pop back to the root view controller.
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    private func setupView() {
        navigationItem.title = Localizable.settings
        view.backgroundColor = .backgroundColor()
        view.layer.backgroundColor = UIColor.backgroundColor().cgColor

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupTableView() {
        genericDataSource = GenericTableViewDataSource(for: tableView, with: viewModel.tableViewData)
        tableView.dataSource = genericDataSource
        tableView.delegate = genericDataSource
        tableView.tableFooterView = viewModel.viewForFooter()
    }

    private func pushViewController(_ viewController: UIViewController, translucentNavBar: Bool, hidesBackButton: Bool) {
        navigationController?.navigationBar.isTranslucent = translucentNavBar
        navigationController?.navigationBar.backgroundColor = translucentNavBar ? .clear : nil

        if hidesBackButton {
            navigationItem.backBarButtonItem = .emptyBackBarButtonItem
        }

        navigationController?.pushViewController(viewController, animated: true)
    }

    // MARK: - Announcements

    private var showAnnouncements: Bool {
        @SharedReader(.featureFlags) var featureFlags
        guard featureFlags.pollNotificationAPI else { return false }
        return announcementManager.shouldShowAnnouncementsIcon()
    }

    private func setupAnnouncements() {
        Task {
            await prefetchAnnouncementImages()
            guard showAnnouncements else {
                if navigationItem.rightBarButtonItem is BadgedBarButtonItem {
                    navigationItem.rightBarButtonItem = nil
                }
                return
            }
            setupAnnouncementsButton()
        }
    }

    private func prefetchAnnouncementImages() async {
        let urls = announcementManager.offerImagePrefetchURLs()
        guard !urls.isEmpty else { return }
        @Dependency(\.imagePrefetcher) var imagePrefetcher
        await imagePrefetcher.prefetchURLs(urls)
    }

    private func setupAnnouncementsButton() {
        let apply: (UIImage) -> Void = { [weak self] image in
            guard let self else { return }
            let button = BadgedBarButtonItem(withImage: image)
            button.onTouchUpInside = {
                AnnouncementOfferCoordinator().presentCurrentAnnouncement()
            }
            button.showBadge = announcementManager.hasUnreadAnnouncements()
            navigationItem.rightBarButtonItem = button
        }

        guard let iconURL = announcementManager.announcementIconURL else {
            apply(Theme.Asset.Icons.bell.image)
            return
        }
        if let cached = SDImageCache.shared.imageFromCache(forKey: iconURL.absoluteString) {
            apply(cached)
            return
        }
        SDWebImageDownloader.shared.downloadImage(with: iconURL) { image, _, _, _ in
            executeOnUIThread {
                guard let image else {
                    apply(Theme.Asset.Icons.bell.image)
                    return
                }
                SDImageCache.shared.store(image, forKey: iconURL.absoluteString, completion: nil)
                apply(image)
            }
        }
    }
}

private extension UIBarButtonItem {
    static let emptyBackBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
}
