//
//  ExpandableContentPopupViewController.swift
//  ProtonVPN - Created on 21/09/2020.
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

class ExpandableContentPopupViewController: NSViewController {
    let viewModel: ExpandablePopupViewModel

    @IBOutlet var actionBtn: CancellationButton!
    @IBOutlet var contentView: NSView!
    @IBOutlet var footerView: NSView!
    @IBOutlet var popupImage: NSImageView!
    @IBOutlet var headerLbl: NSTextField!
    @IBOutlet var expandableLbl: NSTextField!
    @IBOutlet var footerLbl: NSTextField!
    @IBOutlet var displayMoreBtn: InteractiveActionButton!
    @IBOutlet var hiddenContentHeightConstraint: NSLayoutConstraint!

    private var expanded = false
    private var animating = false

    private let closedHeight: CGFloat = 0
    private lazy var expandedHeight: CGFloat = self.expandableLbl.realHeight(self.headerLbl.bounds.width)

    required init(viewModel: ExpandablePopupViewModel) {
        self.viewModel = viewModel
        super.init(nibName: NSNib.Name("ExpandableContentPopup"), bundle: nil)
        viewModel.dismissViewController = { [weak self] in
            DispatchQueue.main.async {
                self?.dismiss(nil)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.title
        actionBtn.title = viewModel.actionButtonTitle
        actionBtn.action = #selector(didPressActionBtn)
        actionBtn.target = self
        popupImage.image = AppTheme.Icon.vpnMainTransparent
        headerLbl.stringValue = viewModel.message
        footerLbl.stringValue = viewModel.extraInfo
        expandableLbl.stringValue = viewModel.hiddenInfo
        expandableLbl.textColor = .color(.text, .weak)
        contentView.wantsLayer = true
        footerView.wantsLayer = true
        DarkAppearance {
            contentView.layer?.backgroundColor = .cgColor(.background)
            footerView.layer?.backgroundColor = .cgColor(.background)
        }
        displayMoreBtn.title = Localizable.moreInfo + "  "
        displayMoreBtn.target = self
        displayMoreBtn.action = #selector(expandBtnTap)
        hiddenContentHeightConstraint.constant = 0
        expandableLbl.alphaValue = 0
    }

    // MARK: - Private

    @objc
    private func didPressActionBtn() {
        if animating { return }
        viewModel.action()
    }

    @objc
    private func expandBtnTap() {
        if animating { return }
        animating = true
        expanded = !expanded

        displayMoreBtn.title = (expanded ? Localizable.lessInfo : Localizable.moreInfo) + "  "
        displayMoreBtn.image = expanded ? AppTheme.Icon.arrowUp : AppTheme.Icon.arrowDown
        hiddenContentHeightConstraint.constant = expanded ? closedHeight : expandedHeight
        expandableLbl.alphaValue = expanded ? 0 : 1
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            self.hiddenContentHeightConstraint.animator().constant = self.expanded ? self.expandedHeight : self.closedHeight
            self.expandableLbl.animator().alphaValue = self.expanded ? 1 : 0
        }, completionHandler: {
            self.animating = false
        })
    }
}
