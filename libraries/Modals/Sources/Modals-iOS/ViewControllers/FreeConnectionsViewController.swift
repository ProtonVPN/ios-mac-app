//
//  Created on 2023-09-06.
//
//  Copyright (c) 2023 Proton AG
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

import Foundation
import UIKit
import Modals
import Overture
import Strings
import Theme

class FreeConnectionsViewController: UIViewController {

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var closeButton: UIButton!
    @IBOutlet private weak var descriptionLabel: UILabel!
    @IBOutlet private weak var subTitleLabel: UILabel!
    @IBOutlet private weak var bannerLabel: UILabel!
    @IBOutlet private weak var bannerImageView: UIImageView!
    @IBOutlet private weak var bannerChevronView: UIImageView!
    @IBOutlet private weak var bannerButton: UIButton!
    @IBOutlet private weak var roundedBackgroundView: UIView!
    @IBOutlet private weak var countriesList: UICollectionView!

    var onBannerPress: (() -> Void)?
    var countries: [(String, Image?)]?

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupDesign()
        setupTranslations()
        countriesList.dataSource = self
    }

    private func setupDesign() {
        view.backgroundColor = .color(.background)
        closeButtonStyle(closeButton)
        topTitleStyle(titleLabel)
        middleSubtitleStyle(subTitleLabel)
        
        descriptionLabel.font = .systemFont(ofSize: 15, weight: .regular)
        descriptionLabel.textColor = .color(.text)
        
        bannerButton.setTitle("", for: .normal)

        // Banner
        bannerTextStyle(bannerLabel)
        bannerChevronView.image = UIImage(systemName: "chevron.right")
        bannerChevronView.tintColor = .color(.text, .weak)

        bannerImageView.image = Modals.Asset.worldwideCoverage.image

        roundedBackgroundView.backgroundColor = .color(.background, .weak)
        roundedBackgroundView.layer.cornerRadius = .themeRadius12
    }

    private func setupTranslations() {
        titleLabel.text = Localizable.freeConnectionsModalTitle
        descriptionLabel.text = Localizable.freeConnectionsModalDescription
        bannerLabel.text = Localizable.freeConnectionsModalBanner
        subTitleLabel.text = Localizable.freeConnectionsModalSubtitle(countries?.count ?? 0)
    }

    // MARK: - Actions

    @IBAction private func bannerButtonTapped(_ sender: Any) {
        onBannerPress?()
    }

    @IBAction private func closeButtonTapped(_ sender: Any) {
        dismiss(animated: true)
    }

}

extension FreeConnectionsViewController: UICollectionViewDataSource {

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return countries?.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CountryCellView.identifier, for: indexPath) as! CountryCellView
        if let country = countries?[indexPath.item] {
            cell.setCountry(country.0, image: country.1)
        }
        return cell
    }
}

// MARK: - View styling

fileprivate let topTitleStyle = concat(centeredTextStyle, and: {
    $0.font = .systemFont(ofSize: 17, weight: .bold)
})

fileprivate let middleSubtitleStyle = concat(baseTextStyle, and: {
    $0.font = .systemFont(ofSize: 17, weight: .bold)
})

fileprivate let bannerTextStyle = concat(baseTextStyle, and: {
    $0.font = .systemFont(ofSize: 13, weight: .regular)
})
