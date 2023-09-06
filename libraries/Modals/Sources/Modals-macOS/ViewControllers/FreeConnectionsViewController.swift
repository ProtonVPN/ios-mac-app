//
//  Created on 2023-09-04.
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

import Cocoa
import Modals

final class FreeConnectionsViewController: NSViewController {

    @IBOutlet private weak var titleLabel: NSTextField!
    @IBOutlet private weak var descriptionLabel: NSTextField!
    @IBOutlet private weak var subTitleLabel: NSTextField!
    @IBOutlet private weak var bannerLabel: NSTextField!
    @IBOutlet private weak var bannerImageView: NSImageView!
    @IBOutlet private weak var bannerChevronView: NSImageView!
    @IBOutlet private weak var roundedBackgroundView: NSView!
    @IBOutlet private weak var countriesList: NSCollectionView!
    @IBOutlet private weak var countriesListLayout: NSCollectionViewFlowLayout!

    var onBannerPress: (() -> Void)?
    var countries: [(String, Image?)]?

    /// Used for calculating size of country cells
    private var _viewForSizing: CountryCellView?

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public init() {
        super.init(nibName: NSNib.Name("FreeConnectionsViewController"), bundle: .module)
    }

    override public func awakeFromNib() {
        super.awakeFromNib()
        view.wantsLayer = true
        view.layer?.backgroundColor = colors.background.cgColor
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupFonts()
        setupImagesAndColors()
        setupCollection()
    }

    override public func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyUpsellModalAppearance()
        setupTranslations()
        countriesList.delegate = self
    }

    private func setupFonts() {
        titleLabel.font = .systemFont(ofSize: 22, weight: .regular)
        titleLabel.textColor = colors.text

        descriptionLabel.font = .systemFont(ofSize: 17, weight: .regular)
        descriptionLabel.textColor = colors.weakText

        subTitleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        subTitleLabel.textColor = colors.text

        bannerLabel.font = .systemFont(ofSize: 13, weight: .regular)
        bannerLabel.textColor = colors.text
    }

    private func setupImagesAndColors() {
        roundedBackgroundView.wantsLayer = true
        roundedBackgroundView.layer?.cornerRadius = 8
        roundedBackgroundView.layer?.backgroundColor = colors.backgroundWeak.cgColor

        bannerImageView.image = Modals.Asset.worldwideCoverage.image
        bannerChevronView.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
    }

    private func setupTranslations() {
        titleLabel.stringValue = LocalizedString.freeConnectionsModalTitle
        descriptionLabel.stringValue = LocalizedString.freeConnectionsModalDescription
        bannerLabel.stringValue = LocalizedString.freeConnectionsModalBanner
        subTitleLabel.stringValue = LocalizedString.freeConnectionsModalSubtitle(countries?.count ?? 0)
    }

    private func setupCollection() {
        countriesList.register(NSNib(nibNamed: CountryCellView.nib, bundle: .module), forItemWithIdentifier: CountryCellView.cellIdentifier)
        countriesList.delegate = self
        countriesList.dataSource = self
        countriesList.backgroundColors = [colors.background]
        countriesListLayout.estimatedItemSize = NSSize(width: 80, height: 16)
    }

    // MARK: - Actions

    @IBAction private func bannerTapped(_ sender: Any) {
        onBannerPress?()
    }
}

// MARK: - NSCollectionViewDataSource

extension FreeConnectionsViewController: NSCollectionViewDataSource {

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return countries?.count ?? 0
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let cell = collectionView.makeItem(withIdentifier: CountryCellView.cellIdentifier, for: indexPath) as! CountryCellView
        if let country = countries?[indexPath.item] {
            cell.setCountry(country.0, image: country.1)
        }
        cell.view.layoutSubtreeIfNeeded()
        return cell
    }
}

// MARK: - NSCollectionViewDelegateFlowLayout

extension FreeConnectionsViewController: NSCollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        guard let cell = viewForSizing else {
            return NSSize(width: 50, height: 16)
        }
        if let country = countries?[indexPath.item] {
            cell.setCountry(country.0, image: country.1)
        }
        return cell.view.fittingSize
    }

    /// Reuse only one view for calculating the size
    private var viewForSizing: CountryCellView? {
        if _viewForSizing == nil {
            var topLevelObjects: NSArray?
            guard Bundle.module.loadNibNamed(CountryCellView.nib, owner: nil, topLevelObjects: &topLevelObjects), let cell = topLevelObjects?.first(where: { $0 is CountryCellView }) as? CountryCellView else {
                return nil
            }
            _viewForSizing = cell
        }
        return _viewForSizing
    }

}
