import SwiftUI
import PhotosUI
import CoreLocation

struct HuntItemRow: View {
    @ObservedObject var item: HuntItemEntity
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var showingOptions = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        HStack(spacing: 14) {
            // Photo thumbnail or placeholder
            PhotoThumbnail(item: item)

            // Item name and status
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.name ?? "Unknown Item")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.textPrimary)

                    if item.isFound {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.found)
                            .font(.body)
                    }
                }

                if item.isFound {
                    VStack(alignment: .leading, spacing: 2) {
                        // Timestamp
                        if let foundAt = item.foundAt {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(.caption2)
                                Text(foundAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                            }
                            .foregroundStyle(Theme.textSecondary)
                        }

                        // Location indicator
                        if item.latitude != 0 || item.longitude != 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.caption2)
                                Text("Location saved")
                                    .font(.caption2)
                            }
                            .foregroundStyle(Theme.accentMint)
                        }
                    }
                }
            }

            Spacer()

            // Camera button (only shown when no photo yet)
            if !item.isFound {
                Image(systemName: "camera.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.lavender)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(Theme.lavenderLight)
                    )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingOptions = true
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: Theme.lavender.opacity(0.2), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(item.isFound ? Theme.found.opacity(0.5) : Theme.lavenderLight, lineWidth: 1.5)
        )
        .confirmationDialog(item.isFound ? "Replace Photo" : "Add Photo", isPresented: $showingOptions) {
            Button("Take Photo") {
                showingCamera = true
            }
            Button("Choose from Library") {
                showingPhotoPicker = true
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingCamera) {
            PhotoCaptureView { image, metadata in
                savePhoto(image, metadata: metadata)
            }
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { oldValue, newValue in
            Task {
                await processSelectedPhoto(newValue)
            }
        }
    }

    private func processSelectedPhoto(_ photoItem: PhotosPickerItem?) async {
        guard let photoItem else { return }

        // Load image data
        guard let data = try? await photoItem.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }

        var metadata = PhotoMetadata()

        // Extract metadata from photo
        if let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {

            // Extract location
            if let gpsData = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
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
            if let exifData = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
               let dateString = exifData[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                metadata.dateTaken = formatter.date(from: dateString)
            }
        }

        await MainActor.run {
            savePhoto(image, metadata: metadata)
        }
    }

    private func savePhoto(_ image: UIImage, metadata: PhotoMetadata) {
        if let data = image.jpegData(compressionQuality: 0.8) {
            item.photoData = data
            item.isFound = true
            item.foundAt = metadata.dateTaken ?? Date()

            if let location = metadata.location {
                item.latitude = location.coordinate.latitude
                item.longitude = location.coordinate.longitude
            }

            try? viewContext.save()
        }
    }

}

struct PhotoThumbnail: View {
    @ObservedObject var item: HuntItemEntity

    var body: some View {
        Group {
            if let photoData = item.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "camera.viewfinder")
                    .font(.title2)
                    .foregroundStyle(Theme.lavender)
            }
        }
        .frame(width: 65, height: 65)
        .background(Theme.lavenderLight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(item.isFound ? Theme.found : Theme.lavenderLight, lineWidth: 2)
        )
    }
}

#Preview {
    List {
        HuntItemRow(item: {
            let context = PersistenceController.preview.container.viewContext
            let item = HuntItemEntity(context: context)
            item.id = UUID()
            item.name = "A red flower"
            item.isFound = false
            return item
        }())

        HuntItemRow(item: {
            let context = PersistenceController.preview.container.viewContext
            let item = HuntItemEntity(context: context)
            item.id = UUID()
            item.name = "A smooth rock"
            item.isFound = true
            return item
        }())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
