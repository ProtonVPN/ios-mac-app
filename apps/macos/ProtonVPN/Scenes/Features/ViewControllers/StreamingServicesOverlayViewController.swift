//
//  StreamingServicesOverlayViewController.swift
//  ProtonVPN - Created on 22.04.21.
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

import Cocoa
import Ergonomics
import LegacyCommon
import Strings
import Theme

final class StreamingServicesOverlayViewController: OverlayViewController {
    @IBOutlet private var streamingIcon: NSImageView!
    @IBOutlet private var countryLbl: NSTextField!
    @IBOutlet private var featuresLbl: NSTextField!
    @IBOutlet private var instructionLbl: NSTextField!
    @IBOutlet private var noteLbl: NSTextField!
    @IBOutlet private var servicesCV: NSCollectionView!
    @IBOutlet private var extraLbl: NSTextField!
    @IBOutlet private var servicesCVHeightConstraint: NSLayoutConstraint!
    @IBOutlet private var dismissButton: HoverDetectionButton!

    private let viewModel: StreamingServicesOverlayViewModelProtocol
    private let cellIdentifier = NSUserInterfaceItemIdentifier("StreamOptionCVItem")

    init(viewModel: StreamingServicesOverlayViewModelProtocol) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let backgroundColor: NSColor = .color(.background)
        streamingIcon.image = AppTheme.Icon.play.colored(.weak)
        countryLbl.stringValue = Localizable.streamingTitle + " - " + viewModel.countryName
        featuresLbl.stringValue = Localizable.featuresTitle
        instructionLbl.stringValue = Localizable.streamingServersDescription
        noteLbl.stringValue = Localizable.streamingServersNote
        extraLbl.stringValue = Localizable.streamingServersExtra
        servicesCV.register(StreamOptionCVItem.self, forItemWithIdentifier: cellIdentifier)
        servicesCV.delegate = self
        servicesCV.dataSource = self
        servicesCV.backgroundColors = [backgroundColor]
        dismissButton.image = AppTheme.Icon.crossSmall
        view.wantsLayer = true
        DarkAppearance {
            view.layer?.backgroundColor = backgroundColor.cgColor
        }
    }

    // MARK: - Actions

    @IBAction
    func didTapDismiss(_ sender: Any) {
        dismiss(sender)
    }
}

extension StreamingServicesOverlayViewController: NSCollectionViewDelegateFlowLayout, NSCollectionViewDataSource {
    // MARK: - NSCollectionViewDelegateFlowLayout

    func collectionView(_: NSCollectionView, layout _: NSCollectionViewLayout, minimumLineSpacingForSectionAt _: Int) -> CGFloat {
        0
    }

    func collectionView(_: NSCollectionView, layout _: NSCollectionViewLayout, minimumInteritemSpacingForSectionAt _: Int) -> CGFloat {
        0
    }

    func collectionView(_ collectionView: NSCollectionView, layout _: NSCollectionViewLayout, sizeForItemAt _: IndexPath) -> NSSize {
        let size = collectionView.frame.width / CGFloat(viewModel.columnsAmount)
        servicesCVHeightConstraint.constant = CGFloat(viewModel.totalRows) * size
        return CGSize(width: size, height: size)
    }

    // MARK: - NSCollectionViewDataSource

    func collectionView(_: NSCollectionView, numberOfItemsInSection _: Int) -> Int {
        viewModel.totalItems
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let cell = collectionView.makeItem(withIdentifier: cellIdentifier, for: indexPath) as! StreamOptionCVItem
        cell.viewModel = viewModel.streamOptionViewModelFor(index: indexPath.item)
        return cell
    }
}
