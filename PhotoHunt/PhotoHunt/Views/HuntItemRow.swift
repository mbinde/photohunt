import SwiftUI
import PhotosUI

struct HuntItemRow: View {
    @ObservedObject var item: HuntItemEntity
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var showingOptions = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        HStack(spacing: 12) {
            // Photo thumbnail or placeholder
            PhotoThumbnail(item: item)
                .onTapGesture {
                    if item.isFound {
                        // If already has photo, show it larger (future feature)
                    } else {
                        showingOptions = true
                    }
                }

            // Item name and status
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name ?? "Unknown Item")
                    .font(.body)
                    .strikethrough(item.isFound)
                    .foregroundStyle(item.isFound ? .secondary : .primary)

                if item.isFound {
                    Text("Found!")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            // Action button
            if !item.isFound {
                Button(action: { showingOptions = true }) {
                    Image(systemName: "camera.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: { clearPhoto() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .confirmationDialog("Add Photo", isPresented: $showingOptions) {
            Button("Take Photo") {
                showingCamera = true
            }
            Button("Choose from Library") {
                showingPhotoPicker = true
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingCamera) {
            PhotoCaptureView { image in
                savePhoto(image)
            }
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { oldValue, newValue in
            Task {
                if let newValue,
                   let data = try? await newValue.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    savePhoto(image)
                }
            }
        }
    }

    private func savePhoto(_ image: UIImage) {
        if let data = image.jpegData(compressionQuality: 0.8) {
            item.photoData = data
            item.isFound = true
            item.foundAt = Date()
            try? viewContext.save()
        }
    }

    private func clearPhoto() {
        item.photoData = nil
        item.isFound = false
        item.foundAt = nil
        try? viewContext.save()
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
                Image(systemName: "photo")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 60, height: 60)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(item.isFound ? Color.green : Color.clear, lineWidth: 2)
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
