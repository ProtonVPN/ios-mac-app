//
//  AnnouncementCell.swift
//  ProtonVPN - Created on 2020-10-09.
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

import UIKit
import AlamofireImage

class AnnouncementCell: UITableViewCell {
    
    enum Style {
        case read
        case unread
        
        var textColor: UIColor {
            switch self {
            case .read: return .protonWhite()
            case .unread: return .protonGreen()
            }
        }
    }
    
    // Views
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var iconView: UIImageView!
            
    override func awakeFromNib() {
        super.awakeFromNib()
        
        backgroundColor = .protonGrey()
        titleLabel.textColor = .protonWhite()
        titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        selectionStyle = .none
    }
    
    // MARK: - Public setters
    
    public var style: Style = .read {
        didSet {
            iconView.tintColor = style.textColor
        }
    }
    
    var title: String? {
        get {
            return titleLabel.text
        }
        set {
            titleLabel.text = newValue
            
            if let newtext = newValue {
                let attributed = NSMutableAttributedString(attributedString: newtext.attributed(withColor: style.textColor, fontSize: 16, alignment: .left))
                let hyphenParagraphStyle = NSMutableParagraphStyle()
                hyphenParagraphStyle.hyphenationFactor = 0.5
                attributed.addAttribute(.paragraphStyle, value: hyphenParagraphStyle, range: NSRange(location: 0, length: newtext.count))
                
                titleLabel.attributedText = attributed
            }
        }
    }
    
    public var imageUrl: String? {
        get {
                return nil
            }
            set {
                let placeholder = UIImage(named: "bullhorn")?.withRenderingMode(.alwaysTemplate)
                if let stringUrl = newValue, let url = URL(string: stringUrl) {
                    iconView.af.setImage(withURL: url, placeholderImage: placeholder, filter: DynamicImageFilter("TemplateImageFilter") { image in
                        return image.withRenderingMode(.alwaysTemplate)
                    })
                } else {
                    iconView.image = placeholder
                }
            }
        }
    
}
