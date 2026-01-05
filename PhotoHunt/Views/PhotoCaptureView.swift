import SwiftUI
import UIKit
import CoreLocation
import ImageIO

struct PhotoMetadata {
    var location: CLLocation?
    var dateTaken: Date?
}

struct PhotoCaptureView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onPhotoTaken: (UIImage, PhotoMetadata) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoCaptureView

        init(_ parent: PhotoCaptureView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            var metadata = PhotoMetadata()

            if let rawMetadata = info[.mediaMetadata] as? [String: Any] {
                // Extract location
                if let gpsData = rawMetadata[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
                    if let lat = gpsData[kCGImagePropertyGPSLatitude as String] as? Double,
                       let latRef = gpsData[kCGImagePropertyGPSLatitudeRef as String] as? String,
                       let lon = gpsData[kCGImagePropertyGPSLongitude as String] as? Double,
                       let lonRef = gpsData[kCGImagePropertyGPSLongitudeRef as String] as? String {
                        let latitude = latRef == "S" ? -lat : lat
                        let longitude = lonRef == "W" ? -lon : lon
                        metadata.location = CLLocation(latitude: latitude, longitude: longitude)
                    }
                }

                // Extract date taken
                if let exifData = rawMetadata[kCGImagePropertyExifDictionary as String] as? [String: Any],
                   let dateString = exifData[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                    metadata.dateTaken = formatter.date(from: dateString)
                }
            }

            if let image = info[.originalImage] as? UIImage {
                parent.onPhotoTaken(image, metadata)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
