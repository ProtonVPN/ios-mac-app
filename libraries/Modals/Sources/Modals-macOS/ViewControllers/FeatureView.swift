//
//  Created on 17/02/2022.
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

import Foundation
import AppKit
import Modals

final class FeatureView: NSView {

    // MARK: Outlets

    @IBOutlet private weak var titleLabel: NSTextField! {
        didSet {
            titleLabel.textColor = colors.text
        }
    }
    @IBOutlet weak var iconImageView: NSImageView!
    @IBOutlet var contentView: NSView!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        setup()
    }

    private func setup() {
        let nib = NSNib(nibNamed: .init(String(describing: type(of: self))), bundle: .module)!
        nib.instantiate(withOwner: self, topLevelObjects: nil)

        translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)
        NSLayoutConstraint.activate([
            trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            topAnchor.constraint(equalTo: contentView.topAnchor),
            bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    // MARK: Properties

    var feature: Feature? {
        didSet {
            iconImageView.image = feature?.image
            titleLabel.stringValue = feature?.title() ?? ""
        }
    }
}
