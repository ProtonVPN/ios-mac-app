//
//  Created on 24/06/2026.
//
//  Copyright (c) 2026 Proton AG
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

import SwiftUI

/// A globe gesture in view coordinates. The catcher below translates native multitouch into these, and the map view
/// turns them into camera moves. Kept platform-neutral so a macOS catcher can feed the same camera logic later.
enum GlobeGesture {
    case dragBegan(CGPoint)
    case dragChanged(CGPoint)
    case dragEnded
    /// A pinch carries both finger positions rather than a scale ratio, so the grabbed points can be locked under the
    /// fingers: the separation drives the zoom and the midpoint drives the pan.
    case pinchBegan(CGPoint, CGPoint)
    case pinchChanged(CGPoint, CGPoint)
    case pinchEnded
    case tap(CGPoint)
}

#if canImport(UIKit)
    import UIKit

    /// Hosts the pan, pinch, and tap recognizers on a plain `UIView` and forwards them as `GlobeGesture`s. UIKit rather
    /// than SwiftUI gestures because a pinch needs the two individual finger positions and `MagnifyGesture` only
    /// exposes a scale ratio, and on iOS 17 there is no way to bridge a UIKit recognizer onto a SwiftUI view
    /// (`UIGestureRecognizerRepresentable` is iOS 18 and up). One view owning all three recognizers also avoids any
    /// hit-test arbitration between SwiftUI and UIKit.
    struct GlobeGestureCatcher: UIViewRepresentable {
        /// Every pan, pinch and tap the globe takes. The map view routes them straight to the camera.
        var onGesture: (GlobeGesture) -> Void

        func makeUIView(context: Context) -> UIView {
            let view = UIView()
            let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan))
            pan.maximumNumberOfTouches = 1 // one finger pans; a second starts the pinch instead
            let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch))
            let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
            for recognizer in [pan, pinch, tap] as [UIGestureRecognizer] {
                recognizer.delegate = context.coordinator
                view.addGestureRecognizer(recognizer)
            }
            return view
        }

        func updateUIView(_: UIView, context: Context) {
            context.coordinator.onGesture = onGesture // freshest closure (captures current view state)
        }

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        final class Coordinator: NSObject, UIGestureRecognizerDelegate {
            var onGesture: ((GlobeGesture) -> Void)?

            @objc
            func handlePan(_ recognizer: UIPanGestureRecognizer) {
                guard let view = recognizer.view else { return }
                let point = recognizer.location(in: view)
                switch recognizer.state {
                case .began: onGesture?(.dragBegan(point))
                case .changed: onGesture?(.dragChanged(point))
                case .ended, .cancelled, .failed: onGesture?(.dragEnded)
                default: break
                }
            }

            @objc
            func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
                guard let view = recognizer.view, recognizer.numberOfTouches >= 2 else {
                    // A finger lifted (or the gesture ended): close the pinch out.
                    if recognizer.state == .ended || recognizer.state == .cancelled || recognizer.state == .failed {
                        onGesture?(.pinchEnded)
                    }
                    return
                }
                let a = recognizer.location(ofTouch: 0, in: view)
                let b = recognizer.location(ofTouch: 1, in: view)
                switch recognizer.state {
                case .began: onGesture?(.pinchBegan(a, b))
                case .changed: onGesture?(.pinchChanged(a, b))
                case .ended, .cancelled, .failed: onGesture?(.pinchEnded)
                default: break
                }
            }

            @objc
            func handleTap(_ recognizer: UITapGestureRecognizer) {
                guard let view = recognizer.view, recognizer.state == .ended else { return }
                onGesture?(.tap(recognizer.location(in: view)))
            }

            // Pan (one touch) and pinch (two touches) already exclude each other by touch count. Letting everything
            // recognize simultaneously keeps the tap from blocking a drag and vice versa. The map view ignores a stray
            // drag while a pinch is active.
            func gestureRecognizer(
                _: UIGestureRecognizer,
                shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
            ) -> Bool {
                true
            }
        }
    }

#elseif canImport(AppKit)
    import AppKit

    /// macOS placeholder so the shared globe code compiles. The interactive map is iOS-only today. A macOS version
    /// would host AppKit recognizers here and forward the same `GlobeGesture`s.
    struct GlobeGestureCatcher: NSViewRepresentable {
        var onGesture: (GlobeGesture) -> Void

        func makeNSView(context _: Context) -> NSView {
            NSView()
        }

        func updateNSView(_: NSView, context _: Context) {}
    }
#endif
