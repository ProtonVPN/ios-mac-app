//
//  Created on 09/03/2022.
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

import Cocoa
import Modals
import Ergonomics

final class DiscourageSecureCoreViewController: NSViewController {

    @IBOutlet private weak var dontShowAgainLabel: NSTextField!
    @IBOutlet private weak var imageView: NSImageView!
    @IBOutlet private weak var titleLabel: NSTextField!
    @IBOutlet private weak var learnMoreButton: NSButton!
    @IBOutlet private weak var descriptionLabel: NSTextField!
    @IBOutlet private weak var activateButton: UpsellPrimaryActionButton!

    private let feature = DiscourageSecureCoreFeature()

    var onDontShowAgain: ((Bool) -> Void)?
    var onActivate: (() -> Void)?
    var onCancel: (() -> Void)?
    var onLearnMore: (() -> Void)?

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public init() {
        super.init(nibName: NSNib.Name("DiscourageSecureCoreView"), bundle: .module)
    }

    override public func awakeFromNib() {
        super.awakeFromNib()
        view.wantsLayer = true
        DarkAppearance {
            view.layer?.backgroundColor = .cgColor(.background)
        }
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        activateButton.title = feature.activate
        setupSubviews()
        setupFeatures()
    }

    func setupSubviews() {
        titleLabel.textColor = .color(.text)
        descriptionLabel.textColor = .color(.text)
    }

    func setupFeatures() {
        titleLabel.stringValue = feature.title
        descriptionLabel.stringValue = feature.subtitle
        imageView.image = feature.artImage
        learnMoreButton.attributedTitle = NSAttributedString(string: feature.learnMore,
                                                             attributes: [.foregroundColor: NSColor.color(.icon, .interactive),
                                                                          .font: NSFont.systemFont(ofSize: 12)])
   }

    override public func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyUpsellModalAppearance()
    }

    @IBAction private func learnMoreButtonTapped(_ sender: Any) {
        onLearnMore?()
    }

    @IBAction func dontShowAgainSwitchToggled(_ sender: NSButton) {
        onDontShowAgain?(sender.state == .on)
    }

    @IBAction private func activateButtonTapped(_ sender: Any) {
        onActivate?()
        dismiss(nil)
    }
}
