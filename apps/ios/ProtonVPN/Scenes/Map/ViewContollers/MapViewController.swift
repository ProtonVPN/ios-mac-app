//
//  SecondViewController.swift
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
import LegacyCommon
import ProtonCoreUIFoundations
import Strings

final class MapViewController: UIViewController {

    private let mapFrame = CGRect(x: 80, y: 104, width: 2600, height: 2206) // correct ratio of Mercator projection map
    
    @IBOutlet private weak var secureCoreBar: UIView!
    @IBOutlet private weak var secureCoreLabel: UILabel!
    @IBOutlet private weak var secureCoreSwitch: ConfirmationToggleSwitch!
    @IBOutlet private weak var mapView: UIImageView!
    @IBOutlet private weak var scrollView: UIScrollView!
    
    var viewModel: MapViewModel?
    
    var lastZoom: CGFloat = 1
    
    private var initialMoveAndZoomDone = false
    private var initialMoveAndZoomFrame = CGRect(x: 1040, y: 500, width: 500, height: 500)
    
    @IBOutlet weak var connectionBarContainerView: UIView!
    public var connectionBarViewController: ConnectionBarViewController?

    override func awakeFromNib() {
        super.awakeFromNib()

        tabBarItem = UITabBarItem(title: Localizable.map, image: IconProvider.map, tag: 1)
        tabBarItem.accessibilityIdentifier = "Map"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.image = Asset.mainMap.image
        
        viewModel?.contentChanged = { [weak self] in self?.contentChanged() }
        viewModel?.connectionStateChanged = { [weak self] in
            DispatchQueue.main.async {
                self?.secureCoreSwitch?.isEnabled = self?.viewModel?.enableViewToggle ?? false
                self?.setConnection()
            }
        }
        viewModel?.reorderAnnotations = { [weak self] in
            DispatchQueue.main.async {
                self?.reorderAnnotations()
            }
        }
        
        setupView()
        setupConnectionBar()
        setupSecureCoreBar()
        addAnnotations()
        setConnection()
        
        NotificationCenter.default.addObserver(self, selector: #selector(setupAnnouncements), name: AnnouncementStorageNotifications.contentChanged, object: nil)
    }
    
    private func setupView() {
        navigationItem.title = Localizable.map
        view.backgroundColor = .backgroundColor()
        
        scrollView.decelerationRate = UIScrollView.DecelerationRate.normal
        scrollView.bouncesZoom = false
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 1.25
        scrollView.delegate = self
        
        if let viewModel = viewModel {
            let gestureRecognizer = UITapGestureRecognizer(target: viewModel, action: #selector(viewModel.mapTapped))
            mapView.addGestureRecognizer(gestureRecognizer)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !initialMoveAndZoomDone {
            scrollView.zoom(to: initialMoveAndZoomFrame, animated: false)
            initialMoveAndZoomDone = true
        }

        setupAnnouncements()
    }
    
    private func setupSecureCoreBar() {
        secureCoreBar.backgroundColor = .backgroundColor()
        secureCoreLabel.textColor = .normalTextColor()
        secureCoreLabel.text = Localizable.useSecureCore
        if let viewModel = viewModel {
            secureCoreSwitch.isEnabled = viewModel.enableViewToggle
            secureCoreSwitch.isOn = viewModel.secureCoreOn
        }
        secureCoreSwitch.tapped = { [weak self] in
            let toOn = self?.viewModel?.secureCoreOn == true
            self?.viewModel?.toggleState(toOn: !toOn) { [weak self] succeeded in
                DispatchQueue.main.async {
                    guard let self = self else {
                        return
                    }

                    self.secureCoreSwitch.setOn(self.viewModel?.secureCoreOn == true, animated: true)

                    if succeeded {
                        self.removeAnnotations()
                        self.addAnnotations()
                    }
                }
            }
        }
    }
    
    private func setupConnectionBar() {
        if let connectionBarViewController = connectionBarViewController {
            connectionBarViewController.embed(in: self, with: connectionBarContainerView)
        }
    }
    
    private func addAnnotations() {
        guard let annotations = viewModel?.annotations else { return }
        
        annotations.forEach { (annotation) in
            let countryAnnotation = CountryAnnotation(frame: CGRect.zero, viewModel: annotation)
            mapView.addSubview(countryAnnotation)
            positionAnnotationInMap(countryAnnotation)
            countryAnnotation.transform = countryAnnotation.transform.scaledBy(x: 1 / scrollView.zoomScale, y: 1 / scrollView.zoomScale)
        }
        
        reorderAnnotations()
    }
    
    private func removeAnnotations() {
        mapView.subviews.forEach { (subview) in
            if let annotationView = subview as? AnnotationView {
                annotationView.removeFromSuperview()
            }
        }
    }
    
    private func setConnection() {
        mapView.subviews.forEach { (subview) in
            if let connectionView = subview as? ConnectionView {
                connectionView.removeFromSuperview()
            }
        }
        
        viewModel?.connections.forEach({ (connection) in
            let connectionView = ConnectionView(frame: CGRect.zero, viewModel: connection)
            mapView.addSubview(connectionView)
            positionConnectionInMap(connectionView)
            connectionView.transform = connectionView.transform.scaledBy(x: 1 / scrollView.zoomScale, y: 1)
        })
        
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
        mapView.subviews.forEach { (subview) in
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
                return annotationView
            } else {
                return nil
            }
        }.sorted { (view1, view2) -> Bool in
            return view1.frame.origin.y < view2.frame.origin.y
        }
        
        let connectedAnnotations: [AnnotationView] = mapView.subviews.compactMap {
            if let annotationView = $0 as? AnnotationView, annotationView.connectedState, !annotationView.selected {
                return annotationView
            } else {
                return nil
            }
        }.sorted { (view1, view2) -> Bool in
            return view1.frame.origin.y < view2.frame.origin.y
        }
        
        let unselectedAnnotations: [AnnotationView] = mapView.subviews.compactMap {
            if let annotationView = $0 as? AnnotationView, !annotationView.selected, !annotationView.connectedState, annotationView.available {
                return annotationView
            } else {
                return nil
            }
        }.sorted { (view1, view2) -> Bool in
            return view1.frame.origin.y < view2.frame.origin.y
        }
        
        let unavailableAnnotations: [AnnotationView] = mapView.subviews.compactMap {
            if let annotationView = $0 as? AnnotationView, !annotationView.selected, !annotationView.connectedState, !annotationView.available {
                return annotationView
            } else {
                return nil
            }
        }.sorted { (view1, view2) -> Bool in
                return view1.frame.origin.y < view2.frame.origin.y
        }
        
        mapView.subviews.forEach { (subview) in
            if let connectionView = subview as? ConnectionView {
                mapView.bringSubviewToFront(connectionView)
            }
        }
        
        unavailableAnnotations.forEach { (view) in
            mapView.bringSubviewToFront(view)
        }
        
        unselectedAnnotations.forEach { (view) in
            mapView.bringSubviewToFront(view)
        }
        
        connectedAnnotations.forEach { (view) in
            mapView.bringSubviewToFront(view)
        }
        
        selectedAnnotations.forEach { (view) in
            mapView.bringSubviewToFront(view)
        }
    }
    
    private func contentChanged() {
        guard let viewModel = viewModel else { return }
        
        secureCoreSwitch.setOn(viewModel.secureCoreOn, animated: true)
        removeAnnotations()
        addAnnotations()
    }
}

extension MapViewController: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return mapView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        resizeAnnotations()
        lastZoom = scrollView.zoomScale
    }
}
