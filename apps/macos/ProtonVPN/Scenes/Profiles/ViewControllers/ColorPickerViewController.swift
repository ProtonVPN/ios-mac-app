//
//  ColorPickerViewController.swift
//  ProtonVPN - Created on 27.06.19.
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

class ColorPickerViewController: NSViewController {
    
    @IBOutlet weak var collectionView: NSCollectionView!
    
    private let backgroundColor = NSColor.protonGrey().cgColor
    private let circleCellWidth: CGFloat = 20.0
    
    var viewModel: ColorPickerViewModel!
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    required init(viewModel: ColorPickerViewModel) {
        super.init(nibName: NSNib.Name("ColorPicker"), bundle: nil)
        self.viewModel = viewModel
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupCollectionView()
    }
    
    override func mouseEntered(with event: NSEvent) {
        collectionView.addCursorRect(collectionView.bounds, cursor: .pointingHand)
    }
    
    override func mouseExited(with event: NSEvent) {
        collectionView.removeCursorRect(collectionView.bounds, cursor: .pointingHand)
    }
    
    private func setupView() {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = backgroundColor
        collectionView.backgroundView = view
    }
    
    private func setupCollectionView() {
        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.itemSize = NSSize(width: circleCellWidth, height: circleCellWidth)
        flowLayout.sectionInset = NSEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
        flowLayout.minimumInteritemSpacing = 0.0
        flowLayout.minimumLineSpacing = 0.0
        
        let trackingArea = NSTrackingArea(rect: collectionView.bounds, options: [NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInKeyWindow],
                                          owner: self, userInfo: nil)
        collectionView.addTrackingArea(trackingArea)
        collectionView.collectionViewLayout = flowLayout
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isSelectable = true
        collectionView.allowsEmptySelection = false
        collectionView.allowsMultipleSelection = false
        
        setSelection()
        
        viewModel.colorSelected = { [unowned self] in self.setSelection() }
    }
    
    private func setSelection() {
        collectionView.selectionIndexPaths = [IndexPath(item: viewModel.selectedColorIndex, section: 0)]
    }
}

extension ColorPickerViewController: NSCollectionViewDataSource {
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.colorCount
    }
    
    func collectionView(_ itemForRepresentedObjectAtcollectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ColorPickerItem"), for: indexPath) as! ColorPickerItemView
        item.colorPickerCircle.color = viewModel.color(atIndex: indexPath.item)
        return item
    }
}

extension ColorPickerViewController: NSCollectionViewDelegate {
    
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        if let index = indexPaths.first?.item {
            viewModel.selectedColorIndex = index
        }
    }
}
