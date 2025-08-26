//
//  MapViewController.swift
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

import CoreLocation
import UIKit

import ProtonCoreUIFoundations

import Announcement
import Domain
import Ergonomics
import LegacyCommon
import Strings

final class MapViewController: UIViewController {
    private let mapFrame = CGRect(x: 80, y: 104, width: 2600, height: 2206) // correct ratio of Mercator projection map

    private var secureCoreBar: UIView = .init().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.backgroundColor = .backgroundColor()
    }

    private var secureCoreLabel: UILabel = .init().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.text = Localizable.useSecureCore
        $0.textColor = .normalTextColor()
    }

    private var secureCoreSwitch: ConfirmationToggleSwitch = .init().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private var mapView: UIImageView = .init().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.contentMode = .scaleAspectFit
        $0.image = Asset.mainMap.image
    }

    private lazy var scrollView: UIScrollView = .init().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.decelerationRate = UIScrollView.DecelerationRate.normal
        $0.bouncesZoom = false
        $0.minimumZoomScale = 0.5
        $0.maximumZoomScale = 1.25
        $0.delegate = self
    }

    var lastZoom: CGFloat = 1

    private var initialMoveAndZoomDone = false
    private var initialMoveAndZoomFrame = CGRect(x: 1040, y: 500, width: 500, height: 500)

    private var connectionBarContainerView: UIView = .init().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    public var connectionBarViewController: ConnectionBarViewController?

    private let viewModel: MapViewModel

    // MARK: - Init

    init(viewModel: MapViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        self.viewModel.contentChanged = { [weak self] in self?.contentChanged() }
        self.viewModel.connectionStateChanged = { [weak self] in
            DispatchQueue.main.async {
                self?.secureCoreSwitch.isEnabled = self?.viewModel.enableViewToggle ?? false
                self?.setConnection()
            }
        }
        self.viewModel.reorderAnnotations = { [weak self] in
            DispatchQueue.main.async {
                self?.reorderAnnotations()
            }
        }

        tabBarItem = UITabBarItem(title: Localizable.map, image: IconProvider.map, tag: 1)
        tabBarItem.accessibilityIdentifier = "Map"
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupConstraints()
        setupConnectionBar()
        setupSecureCoreBar()
        addAnnotations()
        setConnection()

        AppEvent.announcementStorageContent.subscribe(self, selector: #selector(setupAnnouncements))
    }

    private func setupView() {
        navigationItem.title = Localizable.map
        view.backgroundColor = .backgroundColor()

        view.addSubview(connectionBarContainerView)
        view.addSubview(secureCoreBar)
        secureCoreBar.addSubview(secureCoreLabel)
        secureCoreBar.addSubview(secureCoreSwitch)
        view.addSubview(scrollView)
        scrollView.addSubview(mapView)

        let gestureRecognizer = UITapGestureRecognizer(target: viewModel, action: #selector(viewModel.mapTapped))
        mapView.addGestureRecognizer(gestureRecognizer)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            connectionBarContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            connectionBarContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            connectionBarContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            connectionBarContainerView.heightAnchor.constraint(equalToConstant: .themeSpacing48),

            secureCoreBar.topAnchor.constraint(equalTo: connectionBarContainerView.bottomAnchor),
            secureCoreBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            secureCoreBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            secureCoreBar.heightAnchor.constraint(equalToConstant: Dimensions.SecureCoreBar.height),

            secureCoreLabel.leadingAnchor.constraint(equalTo: secureCoreBar.leadingAnchor, constant: .themeSpacing16),
            secureCoreLabel.centerYAnchor.constraint(equalTo: secureCoreBar.centerYAnchor),
            secureCoreLabel.trailingAnchor.constraint(equalTo: secureCoreSwitch.leadingAnchor, constant: -.themeSpacing16),

            secureCoreSwitch.trailingAnchor.constraint(equalTo: secureCoreBar.trailingAnchor, constant: -.themeSpacing16),
            secureCoreSwitch.centerYAnchor.constraint(equalTo: secureCoreBar.centerYAnchor),
            secureCoreSwitch.widthAnchor.constraint(equalToConstant: Dimensions.SecureCoreSwitch.width),
            secureCoreSwitch.heightAnchor.constraint(equalToConstant: Dimensions.SecureCoreSwitch.height),

            scrollView.topAnchor.constraint(equalTo: secureCoreBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            mapView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            mapView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            mapView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !initialMoveAndZoomDone {
            scrollView.zoom(to: initialMoveAndZoomFrame, animated: false)
            initialMoveAndZoomDone = true
        }
    }

    private func setupSecureCoreBar() {
        secureCoreSwitch.isEnabled = viewModel.enableViewToggle
        secureCoreSwitch.isOn = viewModel.secureCoreOn
        secureCoreSwitch.tapped = { [weak self] in
            let toOn = self?.viewModel.secureCoreOn == true
            self?.viewModel.toggleState(toOn: !toOn) { [weak self] succeeded in
                DispatchQueue.main.async {
                    guard let self else {
                        return
                    }

                    self.secureCoreSwitch.setOn(self.viewModel.secureCoreOn, animated: true)

                    if succeeded {
                        self.removeAnnotations()
                        self.addAnnotations()
                    }
                }
            }
        }
    }

    private func setupConnectionBar() {
        if let connectionBarViewController {
            connectionBarViewController.embed(in: self, with: connectionBarContainerView)
        }
    }

    private func addAnnotations() {
        for annotation in viewModel.annotations {
            let countryAnnotation = CountryAnnotation(frame: CGRect.zero, viewModel: annotation)
            mapView.addSubview(countryAnnotation)
            positionAnnotationInMap(countryAnnotation)
            countryAnnotation.transform = countryAnnotation.transform.scaledBy(x: 1 / scrollView.zoomScale, y: 1 / scrollView.zoomScale)
        }

        reorderAnnotations()
    }

    private func removeAnnotations() {
        for subview in mapView.subviews {
            if let annotationView = subview as? AnnotationView {
                annotationView.removeFromSuperview()
            }
        }
    }

    private func setConnection() {
        for subview in mapView.subviews {
            if let connectionView = subview as? ConnectionView {
                connectionView.removeFromSuperview()
            }
        }

        for connection in viewModel.connections {
            let connectionView = ConnectionView(frame: CGRect.zero, viewModel: connection)
            mapView.addSubview(connectionView)
            positionConnectionInMap(connectionView)
            connectionView.transform = connectionView.transform.scaledBy(x: 1 / scrollView.zoomScale, y: 1)
        }

        reorderAnnotations()
    }

    private func positionAnnotationInMap(_ countryAnnotation: CountryAnnotation) {
        let coordinate = countryAnnotation.coordinate
        let locationInView = pointInMap(coordinate)

        let anchorPointY = countryAnnotation.viewModel.anchorPoint.y
        let annotationHeight = countryAnnotation.maxHeight
        countryAnnotation.frame = CGRect(x: locationInView.x - countryAnnotation.width * 0.5, y: locationInView.y - anchorPointY * annotationHeight, width: countryAnnotation.width, height: annotationHeight)
    }

    private func positionConnectionInMap(_ connectionView: ConnectionView) {
        let coordinate1 = connectionView.viewModel.connection.entry.coordinate
        let coordinate2 = connectionView.viewModel.connection.exit.coordinate
        let locationInView1 = pointInMap(coordinate1)
        let locationInView2 = pointInMap(coordinate2)

        connectionView.frame = CGRect(x: min(locationInView1.x, locationInView2.x), y: min(locationInView1.y, locationInView2.y), width: connectionView.width, height: lineLength(from: locationInView1, to: locationInView2))
        let centerX = locationInView1.x + (locationInView2.x - locationInView1.x) * 0.5
        let centerY = locationInView1.y + (locationInView2.y - locationInView1.y) * 0.5
        connectionView.center = CGPoint(x: centerX, y: centerY)
        connectionView.transform = connectionView.transform.rotated(by: lineAngle(between: locationInView1, and: locationInView2))
    }

    private func lineLength(from point1: CGPoint, to point2: CGPoint) -> CGFloat {
        let width = abs(point2.x - point1.x)
        let height = abs(point2.y - point1.y)
        return sqrt(pow(height, 2) + pow(width, 2))
    }

    private func lineAngle(between point1: CGPoint, and point2: CGPoint) -> CGFloat {
        let width = point2.x - point1.x
        let height = point2.y - point1.y
        return atan(height / width) + .pi * 0.5
    }

    private func pointInMap(_ coordinate: CLLocationCoordinate2D) -> CGPoint {
        let latInRad = coordinate.latitude * .pi / 180
        let projectedLat = CGFloat(Foundation.log(tan((.pi / 4) + (latInRad / 2))))
        return CGPoint(x: (CGFloat((coordinate.longitude + 180) / 360) * mapFrame.width - mapFrame.minX) + mapView.bounds.origin.x, y: ((mapFrame.height / 2) - (mapFrame.width * projectedLat / (2 * .pi)) + mapFrame.minY) + mapView.bounds.origin.y)
    }

    private func resizeAnnotations() {
        for subview in mapView.subviews {
            if let countryAnnotation = subview as? AnnotationView {
                countryAnnotation.transform = countryAnnotation.transform.scaledBy(x: lastZoom, y: lastZoom)
                countryAnnotation.transform = countryAnnotation.transform.scaledBy(x: 1 / scrollView.zoomScale, y: 1 / scrollView.zoomScale)
            } else if let connectionView = subview as? ConnectionView {
                connectionView.transform = connectionView.transform.scaledBy(x: lastZoom, y: 1)
                connectionView.transform = connectionView.transform.scaledBy(x: 1 / scrollView.zoomScale, y: 1)
            }
        }
    }

    private func reorderAnnotations() {
        let selectedAnnotations: [AnnotationView] = mapView.subviews.compactMap {
            if let annotationView = $0 as? AnnotationView, annotationView.selected {
                annotationView
            } else {
                nil
            }
        }.sorted { view1, view2 -> Bool in
            return view1.frame.origin.y < view2.frame.origin.y
        }

        let connectedAnnotations: [AnnotationView] = mapView.subviews.compactMap {
            if let annotationView = $0 as? AnnotationView, annotationView.connectedState, !annotationView.selected {
                annotationView
            } else {
                nil
            }
        }.sorted { view1, view2 -> Bool in
            return view1.frame.origin.y < view2.frame.origin.y
        }

        let unselectedAnnotations: [AnnotationView] = mapView.subviews.compactMap {
            if let annotationView = $0 as? AnnotationView, !annotationView.selected, !annotationView.connectedState, annotationView.available {
                annotationView
            } else {
                nil
            }
        }.sorted { view1, view2 -> Bool in
            return view1.frame.origin.y < view2.frame.origin.y
        }

        let unavailableAnnotations: [AnnotationView] = mapView.subviews.compactMap {
            if let annotationView = $0 as? AnnotationView, !annotationView.selected, !annotationView.connectedState, !annotationView.available {
                annotationView
            } else {
                nil
            }
        }.sorted { view1, view2 -> Bool in
            return view1.frame.origin.y < view2.frame.origin.y
        }

        for subview in mapView.subviews {
            if let connectionView = subview as? ConnectionView {
                mapView.bringSubviewToFront(connectionView)
            }
        }

        for view in unavailableAnnotations {
            mapView.bringSubviewToFront(view)
        }

        for view in unselectedAnnotations {
            mapView.bringSubviewToFront(view)
        }

        for view in connectedAnnotations {
            mapView.bringSubviewToFront(view)
        }

        for view in selectedAnnotations {
            mapView.bringSubviewToFront(view)
        }
    }

    private func contentChanged() {
        secureCoreSwitch.setOn(viewModel.secureCoreOn, animated: true)
        removeAnnotations()
        addAnnotations()
    }
}

extension MapViewController: UIScrollViewDelegate {
    func viewForZooming(in _: UIScrollView) -> UIView? {
        mapView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        resizeAnnotations()
        lastZoom = scrollView.zoomScale
    }
}

extension MapViewController {
    private enum Dimensions {
        enum SecureCoreBar {
            static let height: CGFloat = 50
        }

        enum SecureCoreSwitch {
            static let width: CGFloat = 51
            static let height: CGFloat = 31
        }
    }
}
