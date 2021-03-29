//
//  AnnouncementsViewController.swift
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
import vpncore

class AnnouncementsViewController: NSViewController {
    
    // Views
    @IBOutlet weak var backgroundView: NSView!
    @IBOutlet weak var triangleImageView: NSImageView!
    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet weak var scrollViewHeightConstraint: NSLayoutConstraint!
    private var cellHeight: CGFloat = 41.0
    
    // Data
    public var viewModel: AnnouncementsViewModel!
    
    public var closeCallback: (() -> Void)?
    
    required init(viewModel: AnnouncementsViewModel) {
        super.init(nibName: NSNib.Name("AnnouncementsViewController"), bundle: nil)
        self.viewModel = viewModel
        self.viewModel.refreshView = { [weak self] in
            self?.refreshView()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViews()
        setupTableView()
    }
    
    private func setupViews() {
        triangleImageView.image = NSImage(named: "triangle")?.colored(.protonGrey())
        
        view.wantsLayer = true
        
        let shadow = NSShadow()
        shadow.shadowColor = .protonDarkGrey()
        shadow.shadowBlurRadius = 8
        view.shadow = shadow
        view.layer?.masksToBounds = false
        
        backgroundView.layer = CALayer()
        backgroundView.layer?.cornerRadius = 4
        backgroundView.layer?.backgroundColor = NSColor.protonGrey().cgColor
    }
    
    private func setupTableView() {
        scrollView.backgroundColor = .protonGrey()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        // Clip view
        let clipView = NSClipView()
        clipView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentView = clipView
        clipView.pinTo(view: scrollView)
        
        // Document view
        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView
        documentView.wantsLayer = true
        documentView.layer?.backgroundColor = NSColor.protonGrey().cgColor
        
        NSLayoutConstraint(item: scrollView, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: documentView, attribute: NSLayoutConstraint.Attribute.top, multiplier: 1.0, constant: 0.0).isActive = true
        NSLayoutConstraint(item: scrollView, attribute: NSLayoutConstraint.Attribute.trailing, relatedBy: NSLayoutConstraint.Relation.equal, toItem: documentView, attribute: NSLayoutConstraint.Attribute.trailing, multiplier: 1.0, constant: 0.0).isActive = true
        NSLayoutConstraint(item: scrollView, attribute: NSLayoutConstraint.Attribute.leading, relatedBy: NSLayoutConstraint.Relation.equal, toItem: documentView, attribute: NSLayoutConstraint.Attribute.leading, multiplier: 1.0, constant: 0.0).isActive = true
        
        // Content
        documentView.fillVertically(withViews: viewModel.items.map({ return self.rowView(forItem: $0) }))
        
        updateSize()
    }
    
    private func updateSize() {
        scrollViewHeightConstraint.constant = cellHeight * CGFloat(viewModel.items.count)
    }
    
    private func refreshView() {
        setupTableView()
    }
    
    private func rowView(forItem item: Announcement) -> NSView {
        let cell: AnnouncementItemView! = AnnouncementItemView.loadViewFromNib()
        cell.title = item.offer?.label
        cell.imageUrl = item.offer?.icon
        cell.style = item.wasRead ? .read : .unread
        cell.onClick = {
            self.viewModel.open(announcement: item)
            self.close()
        }
        return cell
    }
    
    private func close() {
        closeCallback?()
    }
    
}
