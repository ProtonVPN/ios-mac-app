//
//  MapView.swift
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

class MapView: NSView {
    
    private let imageScale: CGFloat = 8
    private let minMapScale: CGFloat = 0.8
    private let absoluteMinZoom: CGFloat = 1
    private let initialDimensions: CGSize
    
    private let mapView = NSView()
    private let mapLayer = CALayer()
    private let activeConnectionsLayer: CAShapeLayer
    private let inactiveConnectionsLayer: CAShapeLayer
    
    private var translation = CGPoint(x: 0, y: 0)
    private var dimensions: CGSize
    
    private var annotationViews = [MKAnnotationView]()
    private var connections = [ConnectionViewModel]()
    private var homeDistanceFromTop = CGFloat()
    
    var hideConnections = false {
        didSet {
            redrawConnections()
        }
    }
    
    let maxZoom: CGFloat = 8
    var minZoom: CGFloat = 1 {
        didSet {
            didZoom?()
            halfZoom = (maxZoom - minZoom) * 0.6
        }
    }
    var halfZoom: CGFloat = (8 - 1) * 0.6
    var zoom: CGFloat = 1 {
        didSet {
            didZoom?()
        }
    }
        
    var didZoom: (() -> Void)?
    
    override var frame: CGRect {
        didSet {
            mapView.frame = frame
            mapLayer.frame = frame
            mapLayer.removeAllAnimations()
            constrainMap()
            repositionAnnotations()
            redrawConnections()
        }
    }
    
    required init?(coder decoder: NSCoder) {
        let mapImage = MapCoordinateTranslator.mapImage
        
        let mapImageSize = mapImage.representations[0].size
        dimensions = CGSize(width: mapImageSize.width / imageScale, height: mapImageSize.height / imageScale)
        initialDimensions = dimensions
        
        activeConnectionsLayer = CAShapeLayer()
        activeConnectionsLayer.fillColor = NSColor.clear.cgColor
        activeConnectionsLayer.strokeColor = NSColor.protonGreen().cgColor
        
        inactiveConnectionsLayer = CAShapeLayer()
        inactiveConnectionsLayer.fillColor = NSColor.clear.cgColor
        inactiveConnectionsLayer.strokeColor = NSColor.protonLightGrey().cgColor
        
        super.init(coder: decoder)
        
        mapView.layer = CALayer()
        wantsLayer = true
        mapView.layer?.backgroundColor = NSColor.protonMapBackgroundGrey().cgColor
        mapView.layer?.masksToBounds = true
        
        mapView.frame = frame
        mapLayer.frame = frame
        mapLayer.contents = mapImage
        mapLayer.contentsGravity = .center
        
        mapLayer.contentsScale = imageScale
        
        mapView.layer?.addSublayer(mapLayer)
        mapView.layer?.addSublayer(inactiveConnectionsLayer)
        mapView.layer?.addSublayer(activeConnectionsLayer)
        
        addSubview(mapView)
    }
    
    func resize() {
        mapLayer.removeAllAnimations()
        
        repositionAnnotations()
        redrawConnections()
    }
    
    func setHomeDistanceFromTop(_ distance: CGFloat) {
        homeDistanceFromTop = distance
    }
    
    func zoomOutAndCenter() {
        zoom(to: minZoom)
        translateMap(CGPoint(x: 0, y: 0))
    }
    
    override func mouseDragged(with event: NSEvent) {
        let newTranslation = CGPoint(x: translation.x + event.deltaX, y: translation.y - event.deltaY)
        translateMap(newTranslation)
    }
    
    override func scrollWheel(with event: NSEvent) {
        convert(event.locationInWindow, from: nil)
        let scrollDelta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY / 100 : event.scrollingDeltaY / 10
        zoom(pow(2, -scrollDelta), towards: convert(event.locationInWindow, from: nil))
        translateMap(translation)
    }
    
    func zoom(to level: CGFloat) {
        let zoomDelta = level / zoom
        zoom(zoomDelta)
        translateMap(translation)
    }
    
    private func zoom(_ zoomDelta: CGFloat, towards point: CGPoint? = nil) {
        if (zoomDelta < 1 && zoom > minZoom) || (zoomDelta > 1 && zoom < maxZoom) {
            var adjustedZoomDelta = zoomDelta
            if zoomDelta * zoom < minZoom {
                adjustedZoomDelta = minZoom / zoom
            } else if zoomDelta * zoom > maxZoom {
                adjustedZoomDelta = maxZoom / zoom
            }
            
            let pointFromCenter: CGPoint
            if let point = point {
                pointFromCenter = CGPoint(x: (point.x - frame.width / 2), y: (point.y - frame.height / 2))
            } else {
                pointFromCenter = CGPoint(x: 0, y: 0)
            }
            
            zoom *= adjustedZoomDelta
            translation.x = pointFromCenter.x + (adjustedZoomDelta * (translation.x - pointFromCenter.x))
            translation.y = pointFromCenter.y + (adjustedZoomDelta * (translation.y - pointFromCenter.y))
            dimensions.width *= adjustedZoomDelta
            dimensions.height *= adjustedZoomDelta
        }
    }
    
    private func translateMap(_ newTranslation: CGPoint) {
        let leeway = (1 - minMapScale) / 2
        let minTranslationX = (frame.width - dimensions.width) / 2 - leeway * frame.width
        let maxTranslationX = (dimensions.width - frame.width) / 2 + leeway * frame.width
        let minTranslationY = (frame.height - dimensions.height) / 2 - leeway * frame.height
        let maxTranslationY = (dimensions.height - frame.height) / 2 + leeway * frame.height
        
        if newTranslation.x < minTranslationX {
            translation.x = minTranslationX
        } else if newTranslation.x > maxTranslationX {
            translation.x = maxTranslationX
        } else {
            translation.x = newTranslation.x
        }
        
        if dimensions.height < (frame.height - 2 * leeway * frame.height) {
            translation.y = 0.0
        } else if newTranslation.y < minTranslationY {
            translation.y = minTranslationY
        } else if newTranslation.y > maxTranslationY {
            translation.y = maxTranslationY
        } else {
            translation.y = newTranslation.y
        }
        
        repositionMap()
        repositionAnnotations()
        redrawConnections()
    }

    private func constrainMap() {
        if (frame.width * minMapScale) / initialDimensions.width > 1 {
            let newZoom = (frame.width * minMapScale) / initialDimensions.width
            if newZoom >= absoluteMinZoom {
                minZoom = newZoom
            } else {
                minZoom = absoluteMinZoom
            }
            
            if zoom < minZoom {
                let zoomDelta = (frame.width * minMapScale) / dimensions.width
                zoom(zoomDelta)
            }
        }
        
        translateMap(translation)
    }
    
    private func repositionMap() {
        let scale = CATransform3DMakeScale(zoom, zoom, 0)
        let translate = CATransform3DTranslate(scale, translation.x / zoom, translation.y / zoom, 0)
        mapLayer.transform = translate
        
        mapLayer.removeAllAnimations()
    }
    
    func addAnnotationView(_ annotationView: MKAnnotationView) {
        annotationViews.append(annotationView)
        addSubview(annotationView)
        repositionAnnotation(annotationView)
    }
    
    func removeAnnotations(_ annotations: [CountryAnnotationViewModel]) {
        annotations.forEach { (annotation) in
            for (index, annotationView) in annotationViews.enumerated() {
                if let annotationView = annotationView as? CountryAnnotationView, let annotation = annotation as? StandardCountryAnnotationViewModel, annotation === annotationView.viewModel {
                    annotationView.removeFromSuperview()
                    annotationViews.remove(at: index)
                    break
                } else if let annotationView = annotationView as? SCEntryCountryAnnotationView, let annotation = annotation as? SCEntryCountryAnnotationViewModel, annotation === annotationView.viewModel {
                    annotationView.removeFromSuperview()
                    annotationViews.remove(at: index)
                    break
                } else if let annotationView = annotationView as? SCExitCountryAnnotationView, let annotation = annotation as? SCExitCountryAnnotationViewModel, annotation === annotationView.viewModel {
                    annotationView.removeFromSuperview()
                    annotationViews.remove(at: index)
                    break
                }
            }
        }
    }
    
    private func repositionAnnotations() {
        annotationViews.forEach { (annotationView) in
            repositionAnnotation(annotationView)
        }
    }
    
    func setConnections(_ connections: [ConnectionViewModel]) {
        self.connections = connections
        redrawConnections()
    }
    
    private func repositionAnnotation(_ annotationView: MKAnnotationView) {
        let coordinate: CLLocationCoordinate2D
        if let annotationView = annotationView as? CountryAnnotationView {
            coordinate = annotationView.viewModel.coordinate
        } else if let annotationView = annotationView as? SCEntryCountryAnnotationView {
            coordinate = annotationView.viewModel.coordinate
        } else if let annotationView = annotationView as? SCExitCountryAnnotationView {
            coordinate = annotationView.viewModel.coordinate
        } else {
            return
        }
        
        annotationView.setFrameOrigin(translateCoordinateToMap(coordinate))
    }
    
    private func redrawConnections() {
        let connectedPath = CGMutablePath()
        let proposedPath = CGMutablePath()
        var path = connectedPath
        
        guard !hideConnections else {
            activeConnectionsLayer.path = connectedPath
            inactiveConnectionsLayer.path = proposedPath
            return
        }
        
        connections.forEach { (connection) in
            switch connection.state {
            case .connected:
                path = connectedPath
            case .proposed:
                path = proposedPath
            }
            
            switch connection.connection.origin {
            case .home:
                path.move(to: CGPoint(x: frame.origin.x + frame.width / 2, y: frame.origin.y + frame.height - homeDistanceFromTop))
            case .server(let origin):
                path.move(to: translateCoordinateToMap(origin.coordinate))
            }
            
            path.addLine(to: translateCoordinateToMap(connection.connection.destination.coordinate))
        }
        
        activeConnectionsLayer.path = connectedPath
        inactiveConnectionsLayer.path = proposedPath
    }
    
    private func translateCoordinateToMap(_ coordinate: CLLocationCoordinate2D) -> CGPoint {
        let dw = dimensions.width
        let dh = dimensions.height
        let fw = frame.width - frame.origin.x
        let fh = frame.height - frame.origin.y
        let tx = translation.x
        let ty = translation.y
        
        let lat = CGFloat(coordinate.latitude)
        let long = CGFloat(coordinate.longitude)
        
        // Convert to imagespace
        let xOrigin = (long + 180) * (dw / 360) + fw / 2 + tx - dw / 2
        let yOrigin = (lat + 90) * (dh / 180) + fh / 2 + ty - dh / 2
        
        return CGPoint(x: Int(xOrigin), y: Int(yOrigin))
    }
    
    // MARK: - Accessibility
    
    override func accessibilityChildren() -> [Any]? {
        return nil
    }
    
    override func isAccessibilityElement() -> Bool {
        return false
    }
    
}
