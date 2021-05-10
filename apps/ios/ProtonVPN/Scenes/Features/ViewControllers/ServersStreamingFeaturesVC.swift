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

import UIKit
import vpncore

class ServersStreamingFeaturesVC: UIViewController {
    
    private let viewModel: ServersStreamingFeaturesViewModel
    
    @IBOutlet private weak var titleLbl: UILabel!
    @IBOutlet private weak var countryLbl: UILabel!
    @IBOutlet private weak var featuresLbl: UILabel!
    @IBOutlet private weak var instructionLbl: UILabel!
    @IBOutlet private weak var noteLbl: UILabel!
    @IBOutlet private weak var servicesCV: UICollectionView!
    @IBOutlet private weak var extraLbl: UILabel!
    @IBOutlet private weak var servicesCVHeightConstraint: NSLayoutConstraint!

    init( _ viewModel: ServersStreamingFeaturesViewModel ) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        countryLbl.text = LocalizedString.streamingTitle + " - " + viewModel.countryName
        titleLbl.text = LocalizedString.plusServers
        featuresLbl.text = LocalizedString.featuresTitle
        instructionLbl.text = LocalizedString.streamingServersDescription
        noteLbl.text = LocalizedString.streamingServersNote
        extraLbl.text = LocalizedString.streamingServersExtra
        servicesCV.register(StreamingServiceCell.nib, forCellWithReuseIdentifier: StreamingServiceCell.identifier)
        servicesCV.delegate = self
        servicesCV.dataSource = self
        
    }
    
    // MARK: - Actions
    
    @IBAction private func didTapDismiss(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}

extension ServersStreamingFeaturesVC: UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    
    // MARK: - UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let size = collectionView.frame.width / CGFloat(viewModel.columnsAmount)
        servicesCVHeightConstraint.constant = CGFloat(viewModel.totalRows) * size
        return CGSize(width: size, height: size)
    }
    
    // MARK: - UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.totalItems
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StreamingServiceCell.identifier, for: indexPath) as! StreamingServiceCell
        cell.propertiesManager = viewModel.propertiesManager
        cell.service = viewModel.vpnOption(for: indexPath.row)
        return cell
    }
}
