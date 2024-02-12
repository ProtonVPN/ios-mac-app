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
import LegacyCommon
import Theme
import Ergonomics
import Strings

final class StreamingServicesOverlayViewController: OverlayViewController {
    @IBOutlet private weak var streamingIcon: NSImageView!
    @IBOutlet private weak var countryLbl: NSTextField!
    @IBOutlet private weak var featuresLbl: NSTextField!
    @IBOutlet private weak var instructionLbl: NSTextField!
    @IBOutlet private weak var noteLbl: NSTextField!
    @IBOutlet private weak var servicesCV: NSCollectionView!
    @IBOutlet private weak var extraLbl: NSTextField!
    @IBOutlet private weak var servicesCVHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var dismissButton: HoverDetectionButton!
    
    private let viewModel: StreamingServicesOverlayViewModelProtocol
    private let cellIdentifier = NSUserInterfaceItemIdentifier("StreamOptionCVItem")
    
    init( viewModel: StreamingServicesOverlayViewModelProtocol) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
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
    
    @IBAction func didTapDismiss(_ sender: Any) {
        dismiss(sender)
    }
}

extension StreamingServicesOverlayViewController: NSCollectionViewDelegateFlowLayout, NSCollectionViewDataSource {
    
    // MARK: - NSCollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        let size = collectionView.frame.width / CGFloat(viewModel.columnsAmount)
        servicesCVHeightConstraint.constant = CGFloat(viewModel.totalRows) * size
        return CGSize(width: size, height: size)
    }
    
    // MARK: - NSCollectionViewDataSource
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.totalItems
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let cell = collectionView.makeItem(withIdentifier: cellIdentifier, for: indexPath) as! StreamOptionCVItem
        cell.viewModel = viewModel.streamOptionViewModelFor(index: indexPath.item)
        return cell
    }
}
