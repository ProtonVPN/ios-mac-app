//
//  TourController.swift
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

class TourController {
    
    private let sidebarViewController: SidebarViewController
    private let mainWindow: NSWindow
    private let numberPositions: [CGPoint]
    
    private let cardWidth: CGFloat = 250
    private let cardHeight: CGFloat = 220
    
    private var tourViewController: TourViewController!
    private var tourWindowController: TourWindowController!
    private var tourNumberViewController: TourNumberViewController!
    private var tourNumberWindowController: TourWindowController!
    private var page = 1
    
    init(mainWindow: NSWindow, sidebarViewController: SidebarViewController) {
        self.mainWindow = mainWindow
        self.sidebarViewController = sidebarViewController
        self.numberPositions = [CGPoint(x: 320, y: 134), CGPoint(x: 300, y: 197), CGPoint(x: 0, y: 197), CGPoint(x: 230, y: 252), CGPoint(x: 400, y: 80)]
        
        mainWindow.styleMask.remove(.resizable)
        
        let windowRect = mainWindow.frame
        
        // Number window
        tourNumberViewController = TourNumberViewController()
        tourNumberViewController.view.layer?.backgroundColor = NSColor.red.cgColor
        tourNumberWindowController = TourWindowController(viewController: tourNumberViewController)
        mainWindow.addChildWindow(tourNumberWindowController.window!, ordered: .above)
        
        configureNumber()
        
        // Info window
        tourViewController = TourViewController(previous: { [unowned self] in
            self.previous()
        }, next: { [unowned self] in
            self.next()
        })
        tourWindowController = TourWindowController(viewController: tourViewController)
        mainWindow.addChildWindow(tourWindowController.window!, ordered: .above)
        
        tourWindowController.window?.setFrame(CGRect(x: windowRect.maxX, y: windowRect.midY - cardHeight / 2, width: 0, height: cardHeight), display: false)
        DispatchQueue.main.async { [unowned self] in
            self.tourWindowController.window?.setFrame(CGRect(x: windowRect.maxX - self.cardWidth, y: windowRect.midY - self.cardHeight / 2, width: self.cardWidth, height: self.cardHeight), display: true, animate: true)
        }
    }
    
    func close() {
        configureNumber()
        let windowRect = mainWindow.frame
        tourWindowController.window?.setFrame(CGRect(x: windowRect.maxX, y: windowRect.midY - cardHeight / 2, width: 0, height: cardHeight), display: true, animate: true)
        
        tourWindowController.close()
        tourNumberWindowController.close()
        
        mainWindow.styleMask.insert(.resizable)
    }
    
    private func previous() {
        let newPage = page - 1
        guard newPage >= 1 else { return }
        
        page = newPage
        configureNumber()
        tourViewController.display(page: page)
    }
    
    private func next() {
        if page == 5 { // close tour
            close()
        } else {
            let newPage = page + 1
            guard newPage <= 5 else { return }
        
            page = newPage
            configureNumber()
            tourViewController.display(page: page)
        }
    }
    
    private func configureNumber() {
        let numberWidth: CGFloat = 40 + tourNumberViewController.numberView.expansionRadius * 2
        let windowRect = mainWindow.frame
        
        tourNumberWindowController.window?.setFrame(CGRect(x: windowRect.minX + numberPositions[page - 1].x - tourNumberViewController.numberView.expansionRadius, y: windowRect.maxY - numberPositions[page - 1].y - numberWidth + tourNumberViewController.numberView.expansionRadius, width: numberWidth, height: numberWidth), display: true)
        
        if page == 4 { // secure core
            sidebarViewController.setTab(tab: .countries)
        }
        
        tourNumberViewController.display(page: page)
        tourNumberViewController.animate()
    }
}
