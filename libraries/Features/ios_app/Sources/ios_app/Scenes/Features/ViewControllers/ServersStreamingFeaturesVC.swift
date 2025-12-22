//
//  ServersStreamingFeaturesVC.swift
//  ProtonVPN - Created on 20.04.21.
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

class ServersStreamingFeaturesVC: UIViewController {
    private let viewModel: ServersStreamingFeaturesViewModel

    private let titleLbl: UILabel = {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 17)
        label.textColor = .white
        label.textAlignment = .center
        label.tintColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.tintColor = .white
        button.contentEdgeInsets = UIEdgeInsets(top: 3, left: 3, bottom: 3, right: 3)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let featuresLbl: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        label.textColor = UIColor(red: 0.612, green: 0.627, blue: 0.667, alpha: 1.0)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let countryLbl: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let instructionLbl: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = UIColor(red: 0.612, green: 0.627, blue: 0.667, alpha: 1.0)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let noteLbl: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = UIColor(red: 0.612, green: 0.627, blue: 0.667, alpha: 1.0)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let servicesCV: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()

    private let extraLbl: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = UIColor(red: 0.612, green: 0.627, blue: 0.667, alpha: 1.0)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private var servicesCVHeightConstraint: NSLayoutConstraint!

    init(_ viewModel: ServersStreamingFeaturesViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupConstraints()
        configureViews()
    }

    private func setupViews() {
        view.backgroundColor = UIColor(red: 0.145, green: 0.153, blue: 0.173, alpha: 1.0)

        view.addSubview(titleLbl)
        view.addSubview(closeButton)
        view.addSubview(featuresLbl)
        view.addSubview(iconImageView)
        view.addSubview(countryLbl)
        view.addSubview(instructionLbl)
        view.addSubview(noteLbl)
        view.addSubview(servicesCV)
        view.addSubview(extraLbl)
    }

    private func setupConstraints() {
        servicesCVHeightConstraint = servicesCV.heightAnchor.constraint(equalToConstant: Dimensions.ServicesCollectionView.initialHeight)

        NSLayoutConstraint.activate([
            // Title label
            titleLbl.topAnchor.constraint(equalTo: view.topAnchor, constant: Dimensions.titleTop),
            titleLbl.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            titleLbl.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            titleLbl.heightAnchor.constraint(equalToConstant: Dimensions.titleHeight),

            // Close button
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Dimensions.CloseButton.leading),
            closeButton.centerYAnchor.constraint(equalTo: titleLbl.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: Dimensions.CloseButton.size),
            closeButton.heightAnchor.constraint(equalToConstant: Dimensions.CloseButton.size),

            // Features label
            featuresLbl.topAnchor.constraint(equalTo: titleLbl.bottomAnchor, constant: Dimensions.titleToFeaturesSpacing),
            featuresLbl.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: Dimensions.horizontalPadding),
            featuresLbl.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -Dimensions.horizontalPadding),
            featuresLbl.heightAnchor.constraint(equalToConstant: Dimensions.featuresLabelHeight),

            // Icon image view
            iconImageView.topAnchor.constraint(equalTo: featuresLbl.bottomAnchor, constant: Dimensions.featuresToIconSpacing),
            iconImageView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: Dimensions.horizontalPadding),

            // Country label
            countryLbl.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: Dimensions.iconToLabelSpacing),
            countryLbl.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor),
            countryLbl.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -Dimensions.horizontalPadding),

            // Instruction label
            instructionLbl.topAnchor.constraint(equalTo: countryLbl.bottomAnchor, constant: Dimensions.labelSpacing),
            instructionLbl.leadingAnchor.constraint(equalTo: countryLbl.leadingAnchor),
            instructionLbl.trailingAnchor.constraint(equalTo: countryLbl.trailingAnchor),

            // Note label
            noteLbl.topAnchor.constraint(equalTo: instructionLbl.bottomAnchor, constant: Dimensions.labelSpacing),
            noteLbl.leadingAnchor.constraint(equalTo: countryLbl.leadingAnchor),
            noteLbl.trailingAnchor.constraint(equalTo: countryLbl.trailingAnchor),

            // Services collection view
            servicesCV.topAnchor.constraint(equalTo: noteLbl.bottomAnchor, constant: Dimensions.ServicesCollectionView.topSpacing),
            servicesCV.leadingAnchor.constraint(equalTo: countryLbl.leadingAnchor),
            servicesCV.trailingAnchor.constraint(equalTo: countryLbl.trailingAnchor),
            servicesCVHeightConstraint,

            // Extra label
            extraLbl.topAnchor.constraint(equalTo: servicesCV.bottomAnchor, constant: Dimensions.collectionViewToExtraSpacing),
            extraLbl.leadingAnchor.constraint(equalTo: countryLbl.leadingAnchor),
            extraLbl.trailingAnchor.constraint(equalTo: countryLbl.trailingAnchor),
        ])
    }

    private func configureViews() {
        closeButton.setImage(IconProvider.crossBig, for: .normal)
        closeButton.addTarget(self, action: #selector(didTapDismiss), for: .touchUpInside)

        iconImageView.image = IconProvider.play
        countryLbl.text = Localizable.streamingTitle + " - " + viewModel.countryName
        titleLbl.text = Localizable.plusServers
        featuresLbl.text = Localizable.featuresTitle
        instructionLbl.text = Localizable.streamingServersDescription
        noteLbl.text = Localizable.streamingServersNote
        extraLbl.text = Localizable.streamingServersExtra

        servicesCV.register(StreamingServiceCell.self, forCellWithReuseIdentifier: StreamingServiceCell.identifier)
        servicesCV.delegate = self
        servicesCV.dataSource = self
    }

    // MARK: - Actions

    @objc
    private func didTapDismiss() {
        dismiss(animated: true, completion: nil)
    }
}

extension ServersStreamingFeaturesVC: UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    // MARK: - UICollectionViewDataSource

    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, minimumLineSpacingForSectionAt _: Int) -> CGFloat {
        0
    }

    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, minimumInteritemSpacingForSectionAt _: Int) -> CGFloat {
        0
    }

    func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt _: IndexPath) -> CGSize {
        let size = collectionView.frame.width / CGFloat(viewModel.columnsAmount)
        servicesCVHeightConstraint.constant = CGFloat(viewModel.totalRows) * size
        return CGSize(width: size, height: size)
    }

    // MARK: - UICollectionViewDataSource

    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        viewModel.totalItems
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StreamingServiceCell.identifier, for: indexPath) as! StreamingServiceCell
        cell.service = viewModel.vpnOption(for: indexPath.row)
        return cell
    }
}

extension ServersStreamingFeaturesVC {
    private enum Dimensions {
        static let titleTop: CGFloat = 16
        static let titleHeight: CGFloat = 44
        static let titleToFeaturesSpacing: CGFloat = 20
        static let horizontalPadding: CGFloat = 16
        static let featuresLabelHeight: CGFloat = 30
        static let featuresToIconSpacing: CGFloat = 10
        static let iconToLabelSpacing: CGFloat = 8
        static let labelSpacing: CGFloat = 4
        static let collectionViewToExtraSpacing: CGFloat = 16

        enum CloseButton {
            static let leading: CGFloat = 12
            static let size: CGFloat = 24
        }

        enum ServicesCollectionView {
            static let initialHeight: CGFloat = 128
            static let topSpacing: CGFloat = 8
        }
    }
}
