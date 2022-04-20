//
//  CountryAnnotationView.swift
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
import vpncore

private let sqrt3 = sqrt(3)

/// Common class used by all of the different map annotations.
class MapAnnotationView: MKAnnotationView {
    private static let lineWidth = 1.0
    internal static let textLineHeight = 30.0

    internal static let triangleSize: CGSize = {
        let sideLength: CGFloat = 19
        return CGSize(width: sideLength, height: sideLength * sqrt3 / 2)
    }()

    /// Rounded corners: if the triangle is equilateral, then the radius of each arc is
    /// a short side of a 30/60/90 right triangle. The x and y coordinates of the top
    /// side are thus adjusted by the "long" side of this triangle, which is
    /// proportionately scaled by the square root of 3.
    /// https://www.quora.com/What-are-the-properties-of-a-30-60-90-triangle
    ///
    /// Picture a smaller equilateral triangle, aligned with each corner of the equilateral
    /// triangle which creates the annotation. Then divide that triangle into two right
    /// triangles. This is the "corner triangle," or ct. "a" is the shortest side (and also
    /// the corner radius), "b" is the second-shortest, and "c" is the hypotenuse.
    /// theta is equivalent to an angle of 120 degrees (the triangle's corner.)
    /// omega is the offset in the circle where the multiples of theta align with the
    /// triangle's corners, in this case the "top" of the circle because the triangle
    /// is oriented upside-down.
    private typealias CornerOffsets = (a: CGFloat, b: CGFloat, c: CGFloat,
                                       theta: CGFloat, omega: CGFloat)
    private static let triangleCornerOffsets: CornerOffsets = {
        let cornerRadius = 1.9
        return (
            a: cornerRadius,
            b: cornerRadius * sqrt3,
            c: cornerRadius * 2,
            theta: .pi * 2 / 3,
            omega: .pi * 3 / 2
        )
    }()

    internal enum ForegroundOrder: Int {
        case wayBack = -1
        case middle = 50
        case upFront = 100
    }
    /// What tag the object should take on for element ordering when hovered.
    private let hoveredTag: ForegroundOrder

    /// The total size of the button(s) above the triangle (can be multiple for
    /// secure core annotations).
    internal let buttonFrame: CGRect

    /// The rectangular frame around the triangle on the map.
    internal var triangleFrame: CGRect {
        let origin = CGPoint(x: (buttonFrame.size.width - Self.triangleSize.width) / CGFloat(2),
                             y: bounds.height - Self.triangleSize.height)
        return CGRect(origin: origin, size: Self.triangleSize)
    }

    /// The path drawn by the annotation, used to compute whether or not the cursor
    /// is hovering over a triangle or a button.
    internal var path = CGMutablePath()

    /// A delegate for styling the annotation.
    private var styleDelegate: CustomStyleContext

    var _tag = -1
    /// Override the tag to make it writable, so we can change which annotation appears
    /// "on top" on the map.
    override var tag: Int {
        get { _tag }
        set { _tag = newValue }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("Unsupported initializer")
    }

    override required init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        fatalError("Unsupported initializer")
    }

    init(buttonSize: CGSize, hoveredTag: ForegroundOrder, styleDelegate: CustomStyleContext, reuseIdentifier: String?) {
        self.buttonFrame = CGRect(origin: .zero, size: buttonSize)
        self.hoveredTag = hoveredTag
        self.styleDelegate = styleDelegate

        super.init(annotation: nil, reuseIdentifier: reuseIdentifier)
    }

    internal func orderInForeground(hovered: Bool) {
        guard hovered else {
            // default view tag
            tag = ForegroundOrder.wayBack.rawValue
            return
        }

        guard let parentView = superview else {
            return
        }

        tag = hoveredTag.rawValue
        parentView.sortSubviews({ (view1, view2, _) -> ComparisonResult in
            if view1.tag > view2.tag {
                return .orderedDescending
            } else if view1.tag < view2.tag {
                return .orderedAscending
            } else {
                return .orderedSame
            }
        }, context: nil)
    }

    internal func addAnnotationTrackingAreas(hovered: Bool, stateUpdateCallback: @escaping (Bool) -> Void) {
        trackingAreas.forEach { removeTrackingArea($0) }
        let trackingArea = NSTrackingArea(rect: !hovered ? triangleFrame : bounds,
                                          options: [
                                            NSTrackingArea.Options.mouseEnteredAndExited,
                                            NSTrackingArea.Options.mouseMoved,
                                            NSTrackingArea.Options.activeInKeyWindow
                                          ],
                                          owner: self, userInfo: nil)
        addTrackingArea(trackingArea)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let window = self.window {
                let mousePoint = window.mouseLocationOutsideOfEventStream
                let pointInView = self.convert(mousePoint, from: nil)
                if !self.bounds.contains(pointInView) && hovered {
                    stateUpdateCallback(false)
                }
            }
        }
    }

    // swiftlint:disable operator_usage_whitespace
    private func drawButton() {
        let r = AppTheme.ButtonConstants.cornerRadius
        let lineWidth = Self.lineWidth
        // inner button frame
        let ibf = CGRect(x: buttonFrame.origin.x + lineWidth/2,
                         y: buttonFrame.origin.y + lineWidth,
                         width: buttonFrame.size.width - lineWidth,
                         height: buttonFrame.size.height)

        // bottom-right border (triangle in the middle)
        path.addLine(to: CGPoint(x: ibf.maxX - r, y: ibf.maxY))
        // bottom-right corner
        path.addArc(center: CGPoint(x: ibf.maxX - r, y: ibf.maxY - r),
                    radius: r,
                    startAngle: .pi/2,
                    endAngle: 0,
                    clockwise: true)
        // right border
        path.addLine(to: CGPoint(x: ibf.maxX, y: ibf.minY + r))
        // top-right corner
        path.addArc(center: CGPoint(x: ibf.maxX - r, y: ibf.minY + r),
                    radius: r,
                    startAngle: 0,
                    endAngle: .pi*3/2,
                    clockwise: true)
        // top border
        path.addLine(to: CGPoint(x: ibf.minX + r, y: ibf.minY))
        // top-left corner
        path.addArc(center: CGPoint(x: ibf.minX + r, y: ibf.minY + r),
                    radius: r,
                    startAngle: .pi*3/2,
                    endAngle: .pi,
                    clockwise: true)
        // left border
        path.addLine(to: CGPoint(x: ibf.minX, y: ibf.maxY - r))
        // bottom-left corner
        path.addArc(center: CGPoint(x: ibf.minX + r, y: ibf.maxY - r),
                    radius: r,
                    startAngle: .pi,
                    endAngle: .pi/2,
                    clockwise: true)
    }

    // swiftlint:disable function_body_length
    internal func drawAnnotation(context: CGContext, text: [NSAttributedString]) {
        let lineWidth = Self.lineWidth
        let ct = Self.triangleCornerOffsets

        context.setStrokeColor(styleDelegate.cgColor(.icon))
        context.setFillColor(styleDelegate.cgColor(.background))
        context.setLineWidth(lineWidth)

        let tf = triangleFrame
        // "Inner triangle frame." Upside down equilateral triangle with
        // side length == width, height set according to same 30/60/90 rule above.
        // The y-coordinate is offset by the size of the corner triangle's longer
        // side so that the bottom of the rounded corner still rests exactly over
        // the country's coordinate on the map.
        let itf = (
            x: tf.origin.x + lineWidth/2,
            y: tf.origin.y + ct.b,
            w: tf.width - lineWidth,
            h: (tf.width - lineWidth) * sqrt3/2 - lineWidth
        )

        // To keep the bottom side of the hover button horizontal
        let offset = text.isEmpty ? (x: ct.a, y: ct.b) : (x: 0, y: -ct.b + lineWidth)

        path = CGMutablePath()
        // left side (going from top-left corner to bottom corner)
        path.move(to: CGPoint(x: itf.x + offset.x,
                              y: itf.y + offset.y))
        path.addLine(to: CGPoint(x: itf.x + (itf.w - ct.b) / 2,
                                 y: itf.y + itf.h - (3 * ct.a) / 2))
        // bottom corner
        path.addArc(center: CGPoint(x: itf.x + (itf.w / 2),
                                    y: itf.y + itf.h - (2 * ct.a)),
                    radius: ct.a,
                    startAngle: ct.omega - ct.theta,
                    endAngle: ct.omega - (2 * ct.theta),
                    clockwise: true)
        path.addLine(to: CGPoint(x: itf.x + itf.w - offset.x,
                                 y: itf.y + offset.y))

        if !text.isEmpty {
            drawButton()
        } else {
            // top-right corner
            path.addArc(center: CGPoint(x: itf.x + itf.w - ct.b,
                                        y: itf.y + ct.a),
                        radius: ct.a,
                        startAngle: ct.omega - (2 * ct.theta),
                        endAngle: ct.omega,
                        clockwise: true)
            // top border
            path.addLine(to: CGPoint(x: itf.x + ct.b, y: itf.y))
            // top-left corner
            path.addArc(center: CGPoint(x: itf.x + ct.b, y: itf.y + ct.a),
                        radius: ct.a,
                        startAngle: ct.omega,
                        endAngle: ct.omega - ct.theta,
                        clockwise: true)
        }

        // close shape (either top of triangle or last section of button)
        path.closeSubpath()
        context.addPath(path)
        context.drawPath(using: .fillStroke)

        for (index, textLine) in text.enumerated() {
            let textHeight = textLine.size().height
            let textY = Self.textLineHeight * CGFloat(index) + ((Self.textLineHeight - textHeight) / 2)

            textLine.draw(in: CGRect(x: 0, y: textY, width: buttonFrame.size.width, height: textHeight))
        }
    }
    // swiftlint:enable function_body_length operator_usage_whitespace

    internal func mouseInside(with event: NSEvent, hovered: Bool, stateUpdateCallback: @escaping (Bool) -> Void) {
        // hit test before hovering incase a view is obscuring this one already
        guard let hitView = window?.contentView?.hitTest(event.locationInWindow) else { return }

        if hitView === self {
            let pointInView = convert(event.locationInWindow, from: nil)
            if path.contains(pointInView) == true {
                if !hovered {
                    stateUpdateCallback(true)
                }
            } else if hovered {
                stateUpdateCallback(false)
            }
        }

        if hovered {
            resetCursorRects()
            needsDisplay = true
        }
    }

    internal func hitTestForState(_ point: NSPoint, hovered: Bool) -> NSView? {
        let pointInView = point - frame.origin
        let hitTestRect = hovered ? bounds : triangleFrame
        return hitTestRect.contains(pointInView) ? self : nil
    }

    override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin - NSPoint(x: buttonFrame.size.width / 2, y: 0))
    }
}

class CountryAnnotationView: MapAnnotationView {
    let viewModel: StandardCountryAnnotationViewModel

    var hovered: Bool {
        viewModel.state == .hovered
    }

    init(viewModel: StandardCountryAnnotationViewModel, reuseIdentifier: String?) {
        self.viewModel = viewModel
        super.init(buttonSize: CGSize(width: viewModel.buttonWidth,
                                      height: MapAnnotationView.textLineHeight),
                   hoveredTag: .upFront,
                   styleDelegate: viewModel,
                   reuseIdentifier: reuseIdentifier)
        
        viewModel.viewStateChange = { [weak self] in
            guard let `self` = self else { return }
            self.setupAnnotationView()
            self.needsDisplay = true
        }
        
        setupAnnotationView()
    }

    required init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        fatalError("Initializer not supported: \(#function)")
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("Initializer not supported: \(#function)")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        var buttonText: [NSAttributedString] = []
        if hovered {
            let isPointing = NSCursor.current == NSCursor.pointingHand
            buttonText.append(isPointing ? viewModel.attributedConnectTitle : viewModel.attributedCountry)
        }

        drawAnnotation(context: context, text: buttonText)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        return hitTestForState(point, hovered: hovered)
    }
    
    override func mouseEntered(with event: NSEvent) {
        mouseInside(with: event, hovered: hovered, stateUpdateCallback: { (hovered: Bool) in
            self.viewModel.uiStateUpdate(hovered ? .hovered : .idle)
        })
    }
    
    override func mouseMoved(with event: NSEvent) {
        mouseInside(with: event, hovered: hovered, stateUpdateCallback: { (hovered: Bool) in
            self.viewModel.uiStateUpdate(hovered ? .hovered : .idle)
        })
    }

    override func mouseUp(with event: NSEvent) {
        guard hovered else { return }
        let pointInView = convert(event.locationInWindow, from: nil)
        if buttonFrame.contains(pointInView) {
            viewModel.countryConnectAction()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        viewModel.uiStateUpdate(.idle)
    }
    
    override func resetCursorRects() {
        guard hovered else { return }
        addCursorRect(buttonFrame, cursor: .pointingHand)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        addAnnotationTrackingAreas(hovered: hovered, stateUpdateCallback: { hovered in
            self.viewModel.uiStateUpdate(hovered ? .hovered : .idle)
        })
    }

    // MARK: - Private functions
    
    private func setupAnnotationView() {
        setSelection()
        setupFrame()
    }
    
    private func setSelection() {
        if viewModel.state == .idle {
            setSelected(false, animated: false)
        } else {
            setSelected(true, animated: true)
        }
    }
    
    private func setupFrame() {
        let height: CGFloat
        let hovered: Bool
        switch viewModel.state {
        case .idle:
            height = Self.triangleSize.height
            hovered = false
        case .hovered:
            height = Self.triangleSize.height + buttonFrame.size.height
            hovered = true
        }

        orderInForeground(hovered: hovered)
        setFrameSize(NSSize(width: buttonFrame.size.width, height: height))
        centerOffset = NSPoint(x: 0, y: -frame.size.height / 2)
    }
}
