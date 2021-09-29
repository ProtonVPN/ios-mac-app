//
//  LogsViewController.swift
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
import vpncore

class LogsViewController: UIViewController {
    
    @IBOutlet weak var textView: UITextView!
    
    private let viewModel: LogsViewModel
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(viewModel: LogsViewModel) {
        self.viewModel = viewModel
        
        super.init(nibName: "Logs", bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .backgroundColor()
        textView.layoutManager.allowsNonContiguousLayout = false
        textView.backgroundColor = .clear
        textView.font = UIFont.systemFont(ofSize: 12)
        textView.textColor = .normalTextColor()
        textView.text = viewModel.logs
        textView.setContentOffset(CGPoint(x: 0, y: textView.contentSize.height), animated: true)
        
        navigationItem.title = viewModel.title
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(share(_:)))
    }
    
    // MARK: - Private
    @objc private func share(_ item: UIBarButtonItem) {
        let activityViewController = UIActivityViewController(activityItems: [viewModel.logFile], applicationActivities: nil)
        activityViewController.popoverPresentationController?.barButtonItem = item
        navigationController?.present(activityViewController, animated: true, completion: nil)
    }
}
