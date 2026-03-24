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
import Theme

class MapSectionViewController: NSViewController {
    private enum AnnotationIdentifier {
        static let country = "Country"
        static let scEntryCountry = "secureCoreEntryCountry"
        static let scExitCountry = "secureCoreExitCountry"
    }

    private let zoomLevels = Dimensions.zoomLevels

    private let mapHeaderControllerViewContainer = PassThroughView(frame: .zero)
    private let mapView = MapView(frame: .zero)
    private let logoImageView = PassThroughImageView(frame: .zero)
    private let zoomView = ZoomView(frame: .zero)

    private var mapHeaderViewController: MapHeaderViewController!

    private let mapSectionViewModel: MapSectionViewModel
    private let mapHeaderViewModel: MapHeaderViewModel

    // MARK: - Init

    init(mapSectionViewModel: MapSectionViewModel, mapHeaderViewModel: MapHeaderViewModel) {
        self.mapSectionViewModel = mapSectionViewModel
        self.mapHeaderViewModel = mapHeaderViewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Unsupported initializer")
    }

    override func loadView() {
        let rootView = NSView()
        rootView.translatesAutoresizingMaskIntoConstraints = false

        for item in [mapView, logoImageView, zoomView, mapHeaderControllerViewContainer] {
            item.translatesAutoresizingMaskIntoConstraints = false
            rootView.addSubview(item)
        }

        NSLayoutConstraint.activate([
            mapView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            mapView.topAnchor.constraint(equalTo: rootView.topAnchor),
            mapView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            mapHeaderControllerViewContainer.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            mapHeaderControllerViewContainer.topAnchor.constraint(equalTo: rootView.topAnchor),
            mapHeaderControllerViewContainer.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            mapHeaderControllerViewContainer.heightAnchor.constraint(equalToConstant: Dimensions.mapHeaderHeight),

            zoomView.topAnchor.constraint(equalTo: rootView.topAnchor, constant: Dimensions.zoomViewTopOffset),
            zoomView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: Dimensions.zoomViewTrailingOffset),
            zoomView.widthAnchor.constraint(equalToConstant: Dimensions.zoomViewSize),
            zoomView.heightAnchor.constraint(equalToConstant: Dimensions.zoomViewSize),

            logoImageView.centerXAnchor.constraint(equalTo: zoomView.centerXAnchor, constant: Dimensions.logoCenterXOffset),
            zoomView.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: Dimensions.logoTopSpacing),
            logoImageView.widthAnchor.constraint(equalToConstant: Dimensions.logoWidth),
        ])

        view = rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        logoImageView.image = Theme.Asset.vpnWordmarkAlwaysDark.image
        view.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
        view.clipToBounds()

        setupHeader()
        setupMapView()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        if view.frame.width < Dimensions.compactWidthThreshold, zoomView.orientation == .horizontal {
            zoomView.orientation = .vertical
            logoImageView.isHidden = true
        } else if view.frame.width >= Dimensions.compactWidthThreshold, zoomView.orientation == .vertical {
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
            guard let self else {
                return
            }

            mapView.zoomOutAndCenter()
        }

        zoomView.zoomLevels = zoomLevels
        zoomView.zoomInButton.target = self
        zoomView.zoomInButton.action = #selector(zoom(_:))
        zoomView.zoomOutButton.target = self
        zoomView.zoomOutButton.action = #selector(zoom(_:))

        let homeFrame = mapHeaderViewController.connectImage.frame
        mapView.setHomeDistanceFromTop(mapHeaderViewController.view.frame.height - (homeFrame.origin.y + Dimensions.homeDistanceOffset))

        addAnnotations(mapSectionViewModel.annotations)
        setConnections(mapSectionViewModel.connections)

        mapView.didZoom = { [weak self] in
            guard let self else {
                return
            }

            zoomView.zoom = (((mapView.zoom - mapView.minZoom) / (mapView.maxZoom - mapView.minZoom)) * (zoomLevels - 1)).rounded(.toNearestOrAwayFromZero)
        }

        mapSectionViewModel.contentChanged = { [weak self] change in self?.setAnnotations(change) }
        mapSectionViewModel.connectionsChanged = { [weak self] connections in self?.setConnections(connections) }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mapShouldResize),
            name: NSWindow.didChangeBackingPropertiesNotification,
            object: nil
        )
    }

    private func addAnnotations(_ annotations: [CountryAnnotationViewModel]) {
        for annotation in annotations {
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

    @objc
    private func zoom(_ button: ZoomButton) {
        let zoomInterval = (mapView.maxZoom - mapView.minZoom) / (zoomLevels - 1)
        let nextInterval = (mapView.zoom + (button == zoomView.zoomInButton ? zoomInterval : -zoomInterval))
        mapView.zoom(to: nextInterval)
    }

    @objc
    private func mapShouldResize() {
        mapView.resize()
    }

    private func setAnnotations(_ change: AnnotationChange) {
        removeAnnotations(change.oldAnnotations)
        addAnnotations(change.newAnnotations)
        setConnections(mapSectionViewModel.connections)
    }
}

extension MapSectionViewController {
    private enum Dimensions {
        static let zoomLevels: CGFloat = 8
        static let mapHeaderHeight: CGFloat = 100
        static let zoomViewTopOffset: CGFloat = 70
        static let zoomViewTrailingOffset: CGFloat = -40
        static let zoomViewSize: CGFloat = 130
        static let logoCenterXOffset: CGFloat = -1
        static let logoTopSpacing: CGFloat = 10
        static let logoWidth: CGFloat = 124
        static let compactWidthThreshold: CGFloat = 600
        static let homeDistanceOffset: CGFloat = 3
    }
}
