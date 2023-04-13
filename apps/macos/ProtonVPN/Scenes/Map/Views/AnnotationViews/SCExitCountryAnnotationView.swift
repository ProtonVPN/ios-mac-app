//
//  SCExitCountryAnnotationView.swift
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
import Theme_macOS

class SCExitCountryAnnotationView: MapAnnotationView {
    let viewModel: SCExitCountryAnnotationViewModel

    var hovered: Bool {
        viewModel.state == .hovered
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("Unsupported initializer \(#function)")
    }

    required init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        fatalError("Unsupported initializer \(#function)")
    }
    
    init(viewModel: SCExitCountryAnnotationViewModel, reuseIdentifier: String?) {
        self.viewModel = viewModel

        super.init(buttonSize: CGSize(width: viewModel.buttonWidth,
                                      height: MapAnnotationView.textLineHeight * CGFloat(viewModel.servers.count + 1)),
                   hoveredTag: .upFront,
                   styleDelegate: viewModel,
                   reuseIdentifier: reuseIdentifier)

        viewModel.viewStateChange = { [weak self] in
            guard let self = self else {
                return
            }

            self.setupAnnotationView()
            self.needsDisplay = true
        }
        
        setupAnnotationView()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        var text: [NSAttributedString] = []
        if hovered {
            // server titles
            guard let window = window else { return }
            let mousePoint = window.mouseLocationOutsideOfEventStream
            let pointInView = self.convert(mousePoint, from: nil)

            for index in 0..<viewModel.servers.count {
                let itemFrame = CGRect(x: buttonFrame.origin.x,
                                       y: buttonFrame.origin.y + Self.textLineHeight * CGFloat(index),
                                       width: buttonFrame.size.width, height: Self.textLineHeight)

                let inFrame = itemFrame.contains(pointInView)
                let textLine = inFrame ? viewModel.attributedConnectTitle(for: index) : viewModel.attributedServer(for: index)
                text.append(textLine)
            }

            // country title
            text.append(viewModel.attributedCountry)
        }

        super.drawAnnotation(context: context, text: text)
    }
    // swiftlint:enable function_body_length operator_usage_whitespace
    
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
        viewModel.servers.enumerated().forEach { index, _ in
            let itemFrame = CGRect(x: buttonFrame.origin.x, y: buttonFrame.origin.y + Self.textLineHeight * CGFloat(index),
                                   width: buttonFrame.size.width, height: Self.textLineHeight)
            if itemFrame.contains(pointInView) {
                viewModel.serverConnectAction(forRow: index)
            }
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        if hovered {
            viewModel.uiStateUpdate(.idle)
        }
    }
    
    override func resetCursorRects() {
        guard hovered else { return }
        addCursorRect(CGRect(origin: buttonFrame.origin, size: CGSize(width: buttonFrame.width, height: buttonFrame.height - Self.textLineHeight)), cursor: .pointingHand)
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
