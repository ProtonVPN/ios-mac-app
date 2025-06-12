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

    @IBOutlet private var closeButton: UIButton!
    @IBOutlet private var iconImageView: UIImageView!
    @IBOutlet private var titleLbl: UILabel!
    @IBOutlet private var countryLbl: UILabel!
    @IBOutlet private var featuresLbl: UILabel!
    @IBOutlet private var instructionLbl: UILabel!
    @IBOutlet private var noteLbl: UILabel!
    @IBOutlet private var servicesCV: UICollectionView!
    @IBOutlet private var extraLbl: UILabel!
    @IBOutlet private var servicesCVHeightConstraint: NSLayoutConstraint!

    init(_ viewModel: ServersStreamingFeaturesViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        closeButton.setImage(IconProvider.crossBig, for: .normal)
        iconImageView.image = IconProvider.play
        countryLbl.text = Localizable.streamingTitle + " - " + viewModel.countryName
        titleLbl.text = Localizable.plusServers
        featuresLbl.text = Localizable.featuresTitle
        instructionLbl.text = Localizable.streamingServersDescription
        noteLbl.text = Localizable.streamingServersNote
        extraLbl.text = Localizable.streamingServersExtra
        servicesCV.register(StreamingServiceCell.nib, forCellWithReuseIdentifier: StreamingServiceCell.identifier)
        servicesCV.delegate = self
        servicesCV.dataSource = self
        view.backgroundColor = .backgroundColor()
    }

    // MARK: - Actions

    @IBAction private func didTapDismiss(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}

extension ServersStreamingFeaturesVC: UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        0
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        0
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let size = collectionView.frame.width / CGFloat(viewModel.columnsAmount)
        servicesCVHeightConstraint.constant = CGFloat(viewModel.totalRows) * size
        return CGSize(width: size, height: size)
    }

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.totalItems
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StreamingServiceCell.identifier, for: indexPath) as! StreamingServiceCell
        cell.propertiesManager = viewModel.propertiesManager
        cell.service = viewModel.vpnOption(for: indexPath.row)
        return cell
    }
}
