//
//  FeaturesOverlayViewController.swift
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

final class FeaturesOverlayViewController: OverlayViewController {

    @IBOutlet private weak var featuresStackView: NSStackView!
    @IBOutlet private weak var featuresTitleTF: NSTextField!
    @IBOutlet private weak var dismissButton: HoverDetectionButton!

    private let viewModel: FeaturesOverlayViewModelProtocol
    
    init(viewModel: FeaturesOverlayViewModelProtocol) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        featuresTitleTF.attributedStringValue = viewModel.title.styled(.hint, font: .themeFont(.small), alignment: .natural)
        addFeatureRows()
        dismissButton.image = AppTheme.Icon.crossSmall
        view.wantsLayer = true
        DarkAppearance {
            view.layer?.backgroundColor = .cgColor(.background)
        }
    }

    private func addFeatureRows() {
        for featureModel in viewModel.featureViewModels {
            addSectionTitle(sectionTitle: featureModel.sectionTitle)
            addFeatureRow(viewModel: featureModel)
        }
    }

    private func addFeatureRow(viewModel: FeatureCellViewModel) {
        guard let view: FeatureRowView = .loadViewFromNib() else {
            fatalError("Couldn't load FeatureRowView from nib")
        }
        view.viewModel = viewModel
        featuresStackView.addArrangedSubview(view)
    }

    private func addSectionTitle(sectionTitle: String?) {
        guard let sectionTitle = sectionTitle else { return }
        let attributedString = sectionTitle.styled(.hint, font: .themeFont(.small), alignment: .natural)
        let titleTextField = NSTextField(labelWithAttributedString: attributedString)
        featuresStackView.addArrangedSubview(titleTextField)
    }
    
    // MARK: - Actions
    
    @IBAction func didTapDismissBtn(_ sender: Any) {
        dismiss(self)
    }
}
