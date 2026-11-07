//
//  QRCodeService.swift
//  ios_watchme_v9
//
//  Draws the device-sharing QR code on the device. The code only carries the
//  device ID (QRCodeScannerView reads it back), so no server is involved.
//

import UIKit
import CoreImage.CIFilterBuiltins

enum QRCodeService {
    /// Returns a crisp QR code image for `text`, scaled up without smoothing.
    static func image(for text: String, size: CGFloat = 600) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }
        let scale = size / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
