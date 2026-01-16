//
//  TooltipTableViewCell.swift
//  ProtonVPN - Created on 01.07.19.
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

class TooltipTableViewCell: UITableViewCell {
    @IBOutlet var tooltipLabel: UITextView!

    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = .backgroundColor()
        tooltipLabel.textColor = UIColor.weakTextColor()
        tooltipLabel.linkTextAttributes = [
            .foregroundColor: UIColor.textAccent(),
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        selectionStyle = .none
    }

    static func attributedText(for text: String) -> NSAttributedString {
        let string = NSMutableAttributedString(string: text)
        addAttributes(to: string)
        return string
    }

    static func addAttributes(
        to string: NSMutableAttributedString,
        align alignment: NSTextAlignment = .left
    ) {
        string.addTextAttributes(
            withColor: UIColor.weakTextColor(),
            font: UIFont.systemFont(ofSize: 13)
        )

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        string.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: string.string.count)
        )
    }
}
