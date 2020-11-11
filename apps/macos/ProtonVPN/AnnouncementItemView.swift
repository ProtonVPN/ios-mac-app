//
//  AnnouncementItemView.swift
//  ProtonVPN - Created on 2020-10-15.
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
import SDWebImage

class AnnouncementItemView: NSView {

    enum Style {
        case read
        case unread
        
        var textColor: NSColor {
            switch self {
            case .read: return .protonGreyUnselectedWhite()
            case .unread: return .protonGreen()
            }
        }
    }
    
    public var style: Style = .read {
        didSet {
            applyStyle()
        }
    }
    
    public var title: String? {
        get {
            return titleTextField.stringValue
        }
        set {
            titleTextField.stringValue = newValue ?? ""
            applyStyle()
        }
    }
    
    public var imageUrl: String? {
        get {
            return nil
        }
        set {
            let placeholder = NSImage(named: "bullhorn")
            if let stringUrl = newValue, let url = URL(string: stringUrl) {
                imageView.sd_setImage(with: url, placeholderImage: placeholder, options: SDWebImageOptions(rawValue: 0), completed: { image, error, _, _ in
                    self.imageView.image = image?.colored(self.style.textColor)
                })
            } else {
                imageView.image = placeholder?.colored(style.textColor)
            }
        }
    }
    
    public var onClick: (() -> Void)?
    
    // Views
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var titleTextField: NSTextField!
    @IBOutlet weak var cellSurfaceButton: CellSurfaceButton!
    
    // MARK: -
    
    private func applyStyle() {
        titleTextField.textColor = style.textColor
        imageView.image = imageView.image?.colored(style.textColor)
    }
    
    // MARK: - Mouse pointer
    
    override func viewWillMove(toSuperview newSuperview: NSView?) {
        super.viewWillMove(toSuperview: newSuperview)
        setupCellSurfaceButton()
    }
    
    private func setupCellSurfaceButton() {
        cellSurfaceButton.target = self
        cellSurfaceButton.action = #selector(cellSurfaceButtonAction)
    }
    
    @objc func cellSurfaceButtonAction() {
        onClick?()
    }
    
}
