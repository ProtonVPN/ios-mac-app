//
//  MapSectionViewController.swift
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
import MapKit

class MapSectionViewController: NSViewController {
    
    fileprivate struct AnnotationIdentifier {
        static let country = "Country"
        static let scEntryCountry = "secureCoreEntryCountry"
        static let scExitCountry = "secureCoreExitCountry"
    }
    
    private let zoomLevels: CGFloat = 8
    
    @IBOutlet weak var mapHeaderControllerViewContainer: PassThroughView!
    @IBOutlet weak var mapView: MapView!
    @IBOutlet weak var logoImageView: NSImageView!
    @IBOutlet weak var zoomView: ZoomView!
    
    private var mapHeaderViewController: MapHeaderViewController!
    
    var mapSectionViewModel: MapSectionViewModel!
    var mapHeaderViewModel: MapHeaderViewModel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
        
        setupHeader()
        setupMapView()
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        if view.frame.width < 600 && zoomView.orientation == .horizontal {
            zoomView.orientation = .vertical
            logoImageView.isHidden = true
        } else if view.frame.width >= 600 && zoomView.orientation == .vertical {
            zoomView.orientation = .horizontal
            logoImageView.isHidden = false
        }
        
        mapView.hideConnections = mapHeaderViewController.backgroundView.frame.width < mapHeaderViewController.backgroundView.width
    }
    
    // MARK: - Private functions
    private func setupHeader() {
        mapHeaderViewController = MapHeaderViewController(viewModel: mapHeaderViewModel)
        mapHeaderControllerViewContainer.pin(viewController: mapHeaderViewController)
    }
    
    private func setupMapView() {
        mapHeaderViewController.headerClicked = { [weak self] in
            guard let `self` = self else { return }
            
            self.mapView.zoomOutAndCenter()
        }
        
        zoomView.zoomLevels = zoomLevels
        zoomView.zoomInButton.target = self
        zoomView.zoomInButton.action = #selector(zoom(_:))
        zoomView.zoomOutButton.target = self
        zoomView.zoomOutButton.action = #selector(zoom(_:))
        
        let homeFrame = mapHeaderViewController.connectImage.frame
        mapView.setHomeDistanceFromTop(mapHeaderViewController.view.frame.height - (homeFrame.origin.y + 3))
        
        addAnnotations(mapSectionViewModel.annotations)
        setConnections(mapSectionViewModel.connections)
        
        mapView.didZoom = { [weak self] in
            guard let `self` = self else { return }
            
            self.zoomView.zoom = (((self.mapView.zoom - self.mapView.minZoom) / (self.mapView.maxZoom - self.mapView.minZoom)) * (self.zoomLevels - 1)).rounded(.toNearestOrAwayFromZero)
        }
        
        mapSectionViewModel.contentChanged = { [unowned self] change in self.setAnnotations(change) }
        mapSectionViewModel.connectionsChanged = { [unowned self] connections in self.setConnections(connections) }
        
        NotificationCenter.default.addObserver(self, selector: #selector(mapShouldResize),
                                               name: NSWindow.didChangeBackingPropertiesNotification, object: nil)
    }
    
    private func addAnnotations(_ annotations: [CountryAnnotationViewModel]) {
        annotations.forEach { (annotation) in
            // MARK: - Standard country
            if let annotation = annotation as? StandardCountryAnnotationViewModel {
                let annotationView = CountryAnnotationView(viewModel: annotation, reuseIdentifier: AnnotationIdentifier.country)
                mapView.addAnnotationView(annotationView)
            }
            // MARK: - Secure Core entry country
            else if let annotation = annotation as? SCEntryCountryAnnotationViewModel {
                let annotationView = SCEntryCountryAnnotationView(viewModel: annotation, reuseIdentifier: AnnotationIdentifier.scEntryCountry)
                mapView.addAnnotationView(annotationView)
            }
            // MARK: - Secure Core exit country
            else if let annotation = annotation as? SCExitCountryAnnotationViewModel {
                let annotationView = SCExitCountryAnnotationView(viewModel: annotation, reuseIdentifier: AnnotationIdentifier.scExitCountry)
                mapView.addAnnotationView(annotationView)
            }
        }
    }
    
    private func setConnections(_ connections: [ConnectionViewModel]) {
        mapView.setConnections(connections)
    }
    
    private func removeAnnotations(_ annotations: [CountryAnnotationViewModel]) {
        mapView.removeAnnotations(annotations)
    }
    
    @objc private func zoom(_ button: ZoomButton) {
        let zoomInterval = (mapView.maxZoom - mapView.minZoom) / (zoomLevels - 1)
        let nextInterval = (mapView.zoom + (button == zoomView.zoomInButton ? zoomInterval : -zoomInterval))
        mapView.zoom(to: nextInterval)
    }
    
    @objc private func mapShouldResize() {
        mapView.resize()
    }
    
    private func setAnnotations(_ change: AnnotationChange) {
        removeAnnotations(change.oldAnnotations)
        addAnnotations(change.newAnnotations)
        setConnections(mapSectionViewModel.connections)
    }
}
