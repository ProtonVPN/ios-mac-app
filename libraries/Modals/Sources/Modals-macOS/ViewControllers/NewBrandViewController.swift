//
//  Created on 30/03/2022.
//
//  Copyright (c) 2022 Proton AG
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

import AppKit
import Modals

final class NewBrandViewController: NSViewController {

    @IBOutlet private weak var iconBackground: NSImageView!
    @IBOutlet private weak var newBrandBackground: NSImageView!
    @IBOutlet private weak var titleLabel: NSTextField!
    @IBOutlet private weak var subtitleLabel: NSTextField!
    @IBOutlet private weak var readMoreButton: UpsellPrimaryActionButton!

    var onReadMore: (() -> Void)?

    let feature = NewBrandFeature()

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public init() {
        super.init(nibName: NSNib.Name("NewBrandView"), bundle: .module)
    }

    override public func awakeFromNib() {
        super.awakeFromNib()
        view.wantsLayer = true
        view.layer?.backgroundColor = colors.background.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupOutlets()
        setupFeature()
    }

    private func setupOutlets() {
        newBrandBackground.layer?.cornerRadius = 8
        titleLabel.textColor = colors.text
        subtitleLabel.textColor = colors.text
    }

    private func setupFeature() {
        readMoreButton.title = feature.readMore
        iconBackground.image = feature.iconImage
        newBrandBackground.image = feature.artImage
    }

    override public func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyUpsellModalAppearance()
    }

    @IBAction private func readMoreButtonTapped(_ sender: NSButton) {
        onReadMore?()
        dismiss(nil)
    }
}
