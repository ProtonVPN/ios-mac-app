//
//  Created on 23/07/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Cocoa
import SwiftUI

import Ergonomics
import LegacyCommon
import Strings
import Theme

protocol QuickSettingsDetailViewControllerProtocol: AnyObject {
    var arrowIV: NSImageView { get }
    var arrowHorizontalConstraint: NSLayoutConstraint { get }
    var contentBox: NSBox { get }
    var dropdownTitle: NSTextField { get }
    var dropdownDescription: NSTextField { get }
    var dropdownLearnMore: InteractiveActionButton { get }
    var dropdownUpgradeButton: PrimaryActionButton { get }
    var dropdownNote: NSTextField { get }

    func reloadOptions()
    func updateNetshieldStats()
}

class QuickSettingDetailViewController: NSViewController, QuickSettingsDetailViewControllerProtocol {
    var arrowIV: NSImageView = .init().with {
        $0.image = Asset.qsDetailTriangle.image
        $0.contentTintColor = NSColor(rgbHex: 0x43444D)
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.animates = true
        $0.cell?.setAccessibilityElement(false)
        $0.imageScaling = .scaleAxesIndependently
    }

    lazy var arrowHorizontalConstraint: NSLayoutConstraint = arrowIV.centerXAnchor.constraint(equalTo: contentBox.centerXAnchor)

    var contentBox: NSBox = .init().with {
        $0.boxType = .custom
        $0.cornerRadius = 4
        $0.titlePosition = .noTitle
        $0.borderColor = .color(.border, .weak)
        $0.fillColor = .color(.background)
        $0.borderWidth = 1
        $0.cornerRadius = AppTheme.ButtonConstants.cornerRadius
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    var dropdownTitle: NSTextField = .init().with {
        $0.isEditable = false
        $0.isSelectable = false
        $0.isBezeled = false
        $0.drawsBackground = false
        $0.font = NSFont.systemFont(ofSize: 16)
        $0.textColor = .labelColor
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.setAccessibilityIdentifier("QSTitle")
    }

    var dropdownDescription: NSTextField = .init().with {
        $0.isEditable = false
        $0.isSelectable = false
        $0.isBezeled = false
        $0.drawsBackground = false
        $0.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        $0.textColor = .labelColor
        $0.cell?.wraps = true
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.setAccessibilityIdentifier("QSDescription")
    }

    var dropdownLearnMore: InteractiveActionButton = .init().with {
        $0.bezelStyle = .regularSquare
        $0.alignment = .left
        $0.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        $0.fontSize = .small
        $0.title = Localizable.learnMore
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.setAccessibilityIdentifier("LearnMoreButton")
    }

    var dropdownUpgradeButton: PrimaryActionButton = .init(frame: .zero).with {
        $0.bezelStyle = .rounded
        $0.alignment = .center
        $0.contentTintColor = NSColor.white
        $0.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.title = Localizable.upgrade
        $0.actionType = .confirmative
        $0.fontSize = .paragraph
        $0.setAccessibilityIdentifier("UpgradeButton")
    }

    var dropdownNote: NSTextField = .init().with {
        $0.isEditable = false
        $0.isSelectable = false
        $0.isBezeled = false
        $0.drawsBackground = false
        $0.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        $0.textColor = .labelColor
        $0.cell?.wraps = true
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.setAccessibilityIdentifier("QSNote")
    }

    var dropdownNoteImageView: NSImageView = .init().with {
        $0.image = AppTheme.Icon.exclamationTriangleFilled
        $0.wantsLayer = true
        $0.contentTintColor = .color(.icon, .warning)
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.imageScaling = .scaleProportionallyUpOrDown
        $0.isHidden = true
        $0.setContentHuggingPriority(.required, for: .horizontal)
        $0.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    var dropdownNoteStackView: NSStackView = .init().with {
        $0.orientation = .horizontal
        $0.alignment = .top
        $0.spacing = 8
        $0.distribution = .fillProportionally
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private var dropdownOptionsView: NSStackView = .init().with {
        $0.orientation = .vertical
        $0.alignment = .width
        $0.spacing = 8
        $0.distribution = .fillEqually
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.wantsLayer = true
        $0.layer?.masksToBounds = false
    }

    private var buttonsAndNoteView: NSStackView = .init().with {
        $0.orientation = .vertical
        $0.alignment = .centerX
        $0.spacing = 16
        $0.distribution = .fillProportionally
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    lazy var dropdownDescriptionTopViewConstraint: NSLayoutConstraint = dropdownDescription.topAnchor.constraint(equalTo: dropdownTitle.bottomAnchor, constant: 16)

    private var detailBox: NSBox = .init().with {
        $0.boxType = .custom
        $0.borderType = .noBorder
        $0.cornerRadius = 4
        $0.titlePosition = .noTitle
        $0.fillColor = NSColor(white: 1, alpha: 0.0)
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    let presenter: QuickSettingDropdownPresenterProtocol

    // MARK: - Life cycle

    init(_ presenter: QuickSettingDropdownPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.presenter.viewController = self
    }

    override func loadView() {
        super.loadView()
        // Main view
        let shadow = NSShadow()
        shadow.shadowColor = .color(.background)
        shadow.shadowBlurRadius = 8

        view = NSView()
        view.frame = NSRect(x: 0, y: 0, width: 400, height: 414)
        view.wantsLayer = true
        view.layer?.masksToBounds = false
        view.shadow = shadow
        view.layer?.shadowRadius = 5
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupConstraints()

        presenter.viewDidLoad()
        reloadOptions()
    }

    // MARK: - Setup Views

    private func setupViews() {
        // Detail box (outer container)
        view.addSubview(detailBox)

        // Arrow image view
        detailBox.addSubview(arrowIV)

        // Content box
        detailBox.addSubview(contentBox)

        // Title text field
        contentBox.addSubview(dropdownTitle)

        // Description text field
        contentBox.addSubview(dropdownDescription)

        // Learn more button
        contentBox.addSubview(dropdownLearnMore)

        // Note text field
        [dropdownNoteImageView, dropdownNote].forEach(dropdownNoteStackView.addArrangedSubview)

        // Options view + note
        [dropdownOptionsView, dropdownUpgradeButton, dropdownNoteStackView].forEach(buttonsAndNoteView.addArrangedSubview)
        contentBox.addSubview(buttonsAndNoteView)
    }

    // MARK: - Setup Constraints

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Detail box constraints
            detailBox.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            detailBox.topAnchor.constraint(equalTo: view.topAnchor),
            detailBox.widthAnchor.constraint(equalTo: view.widthAnchor),
            detailBox.heightAnchor.constraint(equalTo: view.heightAnchor),

            // Arrow image view constraints
            arrowIV.topAnchor.constraint(equalTo: detailBox.topAnchor, constant: 4),
            arrowIV.widthAnchor.constraint(equalToConstant: 30),
            arrowIV.heightAnchor.constraint(equalTo: arrowIV.widthAnchor, multiplier: 6 / 18),

            // Content box constraints
            contentBox.topAnchor.constraint(equalTo: arrowIV.bottomAnchor, constant: -1),
            contentBox.leadingAnchor.constraint(equalTo: detailBox.leadingAnchor, constant: 20),
            contentBox.trailingAnchor.constraint(equalTo: detailBox.trailingAnchor, constant: -20),
            contentBox.bottomAnchor.constraint(lessThanOrEqualTo: detailBox.bottomAnchor, constant: -7),

            // Title text field constraints
            dropdownTitle.topAnchor.constraint(equalTo: contentBox.topAnchor, constant: 24),
            dropdownTitle.leadingAnchor.constraint(equalTo: contentBox.leadingAnchor, constant: 16),
            dropdownTitle.trailingAnchor.constraint(equalTo: contentBox.trailingAnchor, constant: -16),

            // Description text field constraints
            dropdownDescriptionTopViewConstraint,
            dropdownDescription.leadingAnchor.constraint(equalTo: dropdownTitle.leadingAnchor),
            dropdownDescription.trailingAnchor.constraint(equalTo: dropdownTitle.trailingAnchor),

            // Learn more button constraints
            dropdownLearnMore.topAnchor.constraint(equalTo: dropdownDescription.bottomAnchor, constant: 4),
            dropdownLearnMore.leadingAnchor.constraint(equalTo: dropdownTitle.leadingAnchor),
            dropdownLearnMore.heightAnchor.constraint(equalToConstant: 15),

            // Options view constraints
            buttonsAndNoteView.topAnchor.constraint(equalTo: dropdownLearnMore.bottomAnchor, constant: 12),
            buttonsAndNoteView.leadingAnchor.constraint(equalTo: dropdownLearnMore.leadingAnchor),
            buttonsAndNoteView.trailingAnchor.constraint(equalTo: dropdownTitle.trailingAnchor),
            buttonsAndNoteView.bottomAnchor.constraint(equalTo: contentBox.bottomAnchor, constant: -16),

            // Upgrade button constraints
            dropdownUpgradeButton.heightAnchor.constraint(equalToConstant: 33),

            dropdownOptionsView.widthAnchor.constraint(equalTo: buttonsAndNoteView.widthAnchor),
            dropdownNoteStackView.widthAnchor.constraint(equalTo: buttonsAndNoteView.widthAnchor),
        ])

        // Arrow horizontal constraint
        arrowHorizontalConstraint.isActive = true

        // Alternative description constraint
        let alternativeDescriptionConstraint = dropdownDescription.topAnchor.constraint(equalTo: dropdownTitle.bottomAnchor, constant: 16)
        alternativeDescriptionConstraint.priority = NSLayoutConstraint.Priority(999)
        alternativeDescriptionConstraint.isActive = true
    }

    // MARK: - Utils

    func updateNetshieldStats() {}

    func reloadOptions() {
        var needsUpgrade = false
        let views: [QuickSettingsDropdownOption] = presenter.options.enumerated().map { _, presenter in
            let thisNeedsUpgrade = presenter.requiresUpdate ?? false
            defer { needsUpgrade = thisNeedsUpgrade || needsUpgrade }

            let view: QuickSettingsDropdownOption? = QuickSettingsDropdownOption.loadViewFromNib()
            view?.titleLabel.stringValue = presenter.title
            view?.optionIconIV.image = presenter.icon
            if thisNeedsUpgrade {
                view?.blockedStyle()
                view?.action = { [weak self] in
                    presenter.selectCallback {
                        self?.presenter.dismiss?()
                    }
                }
            } else {
                if presenter.active {
                    view?.selectedStyle()
                } else {
                    view?.disabledStyle()
                    view?.action = { [weak self] in
                        presenter.selectCallback {
                            self?.presenter.dismiss?()
                        }
                    }
                }
            }
            return view!
        }

        dropdownOptionsView.subviews.forEach { $0.removeFromSuperview() }
        for view in views {
            dropdownOptionsView.addArrangedSubview(view)
            NSLayoutConstraint.activate([
                view.widthAnchor.constraint(equalTo: dropdownOptionsView.widthAnchor),
            ])
        }

        dropdownUpgradeButton.isHidden = !needsUpgrade
        dropdownNoteStackView.isHidden = dropdownNote.attributedStringValue.length < 1
    }
}
