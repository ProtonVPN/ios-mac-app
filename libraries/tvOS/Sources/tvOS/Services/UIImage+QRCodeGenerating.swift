//
//  Created on 26/04/2024.
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

import UIKit
import CoreImage.CIFilterBuiltins
import Theme

extension UIImage {
    static func generateQRCode(from string: String, foregroundColor: UIColor) -> UIImage {
        let color0 = CIColor(color: foregroundColor)
        guard let qrCode = qrCode(string),
              let colored = colored(qrCode, color0: color0),
              let cgImage = CIContext().createCGImage(colored, from: colored.extent) else {
            return UIImage(systemName: "xmark.circle") ?? UIImage()
        }
        return UIImage(cgImage: cgImage)
    }

    private static func qrCode(_ message: String) -> CIImage? {
        let qrCodeGenerator = CIFilter.qrCodeGenerator()
        qrCodeGenerator.message = Data(message.utf8)
        return qrCodeGenerator.outputImage
    }

    private static func colored(_ image: CIImage?, color0: CIColor) -> CIImage? {
        let falseColorFilter = CIFilter.falseColor()
        falseColorFilter.color0 = color0
        // This is done so that we can have custom margin value
        // background color, remember to provide a background down the line
        falseColorFilter.color1 = .clear
        falseColorFilter.inputImage = image
        return falseColorFilter.outputImage
    }
}
