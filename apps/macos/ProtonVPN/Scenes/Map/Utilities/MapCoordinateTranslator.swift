//
//  MapCoordinateTranslator.swift
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
import CoreLocation

struct MapCoordinateTranslator {
    
    // Unfortunately there seems to be a rendering bug with pdf here (around the edges of vectors, and is inconsistent)
    static let mapImage = #imageLiteral(resourceName: "world-map")
    
    static func mapImageCoordinate(from coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        
        // MARK: Convert to Miller Cylindrical map projection
        
        let latRadians = (coordinate.latitude) / 180 * .pi
        
        // Miller cylindrical projection formula
        let latMillerRadians = 1.25 * log(tan(0.25 * .pi + 0.4 * latRadians))
        let latMillerDegrees = (latMillerRadians / .pi) * 180
        
        // MARK: Offset for the incomplete map
        
        /**
         * Updating image instructions:
         *
         * If the image changes in resolution (proportions remain the same),
         * multiply the imageOriginSffset and realMapSize by the proportional change.
         * e.g. image dimensions both double, imageOriginSffset and realMapSize values should double.
         *
         * Otherwise, get imageOriginOffset and realMapSize by overlaying a full
         * Miller Cylindrical projection
         * (https://map-projections.net/img/gruen-w/tobler-cylindrical-1.png) on
         * top of the actual map image at desired resolution.
         *
         *  ----------------------------------
         *  | -----------------              |
         *  | |               |              |
         *  | |               |              |
         *  | -----------------              |
         *  | ←--image width--→   ↑          |
         *  |                     | offset.y |
         *  |                     ↓          |
         *  ----------------------------------
         *  ←---------real map width---------→
        **/
        
        let realMapWidth = 3116.0 * 2
        let realMapHeight = 2250.0 * 2
        let imageOriginOffsetX = 0.0 * 2
        let imageOriginOffsetY = 558.0 * 2
        
        let mapImageSize = mapImage.representations[0].size
        let imageWidth = Double(mapImageSize.width)
        let imageHeight = Double(mapImageSize.height)
        
        let maxMillerRadians = 2.303412543
        let maxMillerDegrees = (maxMillerRadians / .pi) * 180
        let rangeMillerDegrees = maxMillerDegrees * 2
        
        let longOffsetForImage = 360 / (imageWidth / (((coordinate.longitude + 180) / 360) * realMapWidth - imageOriginOffsetX)) - 180
        let latOffsetForImageMiller = rangeMillerDegrees / (imageHeight / (((latMillerDegrees + maxMillerDegrees) / rangeMillerDegrees) * realMapHeight - imageOriginOffsetY)) - maxMillerDegrees
        
        // Convert from Miller space back to standard so that it can be used in a standard coordinate space
        let latOffsetForImage = (latOffsetForImageMiller / maxMillerDegrees) * 90
        
        return CLLocationCoordinate2D(latitude: latOffsetForImage, longitude: longOffsetForImage)
    }
    
}
