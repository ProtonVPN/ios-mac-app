//
//  Created on 26/09/2024.
//
//  Copyright (c) 2024 Proton AG
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

import Foundation
import CoreLocation

/// Implemented according to the definition from https://en.wikipedia.org/wiki/Natural_Earth_projection
public enum NaturalEarthProjection {
    private static func rad(fromDegrees value: Double) -> Double {
        Measurement(value: value, unit: UnitAngle.degrees).converted(to: .radians).value
    }

    private static func lPolynomial(lat: Double, long: Double) -> Double {
        var sum = 0.870700
        sum -= 0.131979 * lat^^2
        sum -= 0.013791 * lat^^4
        sum += 0.003971 * lat^^10
        sum -= 0.001529 * lat^^12
        return sum * long
    }

    private static func dPolynomial(lat: Double) -> Double {
        var sum = 1.007226
        sum += 0.015085 * lat^^2
        sum -= 0.044475 * lat^^6
        sum += 0.028874 * lat^^8
        sum -= 0.005916 * lat^^10
        return sum * lat
    }

    private static func x(lat: Double, long: Double) -> Double {
        lPolynomial(lat: rad(fromDegrees: lat), long: rad(fromDegrees: long))
    }

    private static func y(lat: Double) -> Double {
        dPolynomial(lat: rad(fromDegrees: lat))
    }

    private static let rangeX = abs(-2.73539) + 2.73539
    private static let rangeY = abs(-1.42239) + 1.42239

    static public func projection(from coordinates: CLLocationCoordinate2D, in space: CGSize) -> CGPoint {
        let pointX = x(lat: coordinates.latitude, long: coordinates.longitude)
        let pointY = y(lat: coordinates.latitude)
        let ratioX = space.width / rangeX
        let ratioY = space.height / rangeY
        return CGPoint(x: pointX * ratioX, y: pointY * ratioY)
    }
}

precedencegroup PowerPrecedence { higherThan: MultiplicationPrecedence }
infix operator ^^ : PowerPrecedence
fileprivate func ^^ (radix: Double, power: Int) -> Double {
    pow(radix, Double(power))
}
