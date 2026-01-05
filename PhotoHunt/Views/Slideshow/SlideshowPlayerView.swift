import SwiftUI
import AVKit
import CoreData
import Photos

struct SlideshowPlayerView: View {
    let videoURL: URL
    let huntName: String
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var showShareSheet = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView("Loading...")
                    .foregroundStyle(.white)
            }

            // Overlay controls
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .frame(width: 44, height: 44)

                    Spacer()

                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            player = AVPlayer(url: videoURL)
            player?.play()

            // Loop playback
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player?.currentItem,
                queue: .main
            ) { _ in
                player?.seek(to: .zero)
                player?.play()
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [videoURL])
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// View for generating and showing slideshow
struct SlideshowGeneratorView: View {
    let huntList: HuntListEntity
    @Environment(\.dismiss) private var dismiss
    @StateObject private var generator = SlideshowGenerator()
    @State private var videoURL: URL?
    @State private var showPlayer = false
    @State private var polaroidPercentage: Double = 0.67  // Default 67% polaroid
    @State private var secondsPerPhoto: Double = 4.0  // Default 4 seconds
    @State private var generationStarted = false
    @State private var currentQuipIndex = 0

    private let loadingQuips = [
        "Sprinkling pixie dust on your photos...",
        "Teaching your photos to dance...",
        "Convincing pixels to cooperate...",
        "Adding that chef's kiss...",
        "Herding cats (the digital kind)...",
        "Brewing a fresh batch of memories...",
        "Polishing each pixel by hand...",
        "Asking the photos to smile...",
        "Applying generous amounts of movie magic...",
        "Wrangling rogue pixels...",
        "Giving your photos their big break...",
        "Rolling out the red carpet...",
        "Making your memories look fancy...",
        "Assembling the dream team of photos...",
        "Adding a dash of nostalgia..."
    ]

    var body: some View {
        // Show player fullscreen when ready, otherwise show the generator UI
        if showPlayer, let url = videoURL {
            SlideshowPlayerView(videoURL: url, huntName: huntList.name ?? "Photo Hunt")
                .onDisappear {
                    // Reset state when player is dismissed
                    generationStarted = false
                    videoURL = nil
                    showPlayer = false
                }
        } else {
            generatorView
        }
    }

    private var generatorView: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    if generator.isGenerating {
                        // Progress view - generating
                        VStack(spacing: 16) {
                            ProgressView(value: generator.progress) {
                                Text("Creating your slideshow...")
                                    .font(.headline)
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            .progressViewStyle(.linear)
                            .tint(Theme.lavender)

                            Text("\(Int(generator.progress * 100))%")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.lavender)

                            Text(loadingQuips[currentQuipIndex])
                                .font(.subheadline)
                                .foregroundStyle(Theme.textPrimary.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .animation(.easeInOut, value: currentQuipIndex)
                        }
                        .padding(40)
                        .onAppear {
                            currentQuipIndex = Int.random(in: 0..<loadingQuips.count)
                        }
                        .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
                            withAnimation {
                                currentQuipIndex = (currentQuipIndex + 1) % loadingQuips.count
                            }
                        }
                    } else if generationStarted && videoURL != nil && !showPlayer {
                        // Generation complete, saving to photos / preparing to show
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(Theme.lavender)

                            Text("Saving to Photos...")
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)

                            Text("Your slideshow will play shortly")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textPrimary.opacity(0.7))
                        }
                        .padding(40)
                    } else if let error = generator.errorMessage {
                        // Error view
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundStyle(.red)

                            Text("Error creating slideshow")
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)

                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textPrimary.opacity(0.7))
                                .multilineTextAlignment(.center)

                            Button("Try Again") {
                                generateSlideshow()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.lavender)
                        }
                        .padding(40)
                    } else {
                        // Ready to generate
                        ScrollView {
                            VStack(spacing: 20) {
                                Image(systemName: "film.stack")
                                    .font(.system(size: 70))
                                    .foregroundStyle(Theme.textPrimary)

                                Text("Create Slideshow")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Theme.textPrimary)

                                Text("Turn your \(huntList.name ?? "hunt") photos into a video slideshow!")
                                    .font(.body)
                                    .foregroundStyle(Theme.textPrimary.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)

                                let foundItems = huntList.itemsArray.filter { $0.isFound }
                                Text("\(foundItems.count) photos")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Theme.textPrimary)

                                // Style slider
                                VStack(spacing: 12) {
                                    Text("Photo Style Mix")
                                        .font(.headline)
                                        .foregroundStyle(Theme.textPrimary)

                                    HStack {
                                        VStack {
                                            Image(systemName: "photo.on.rectangle.angled")
                                                .font(.title2)
                                            Text("Cinematic")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundStyle(polaroidPercentage < 0.5 ? Theme.textPrimary : Theme.textPrimary.opacity(0.5))

                                        Slider(value: $polaroidPercentage, in: 0...1)
                                            .tint(Theme.lavender)

                                        VStack {
                                            Image(systemName: "photo.artframe")
                                                .font(.title2)
                                            Text("Polaroid")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundStyle(polaroidPercentage > 0.5 ? Theme.textPrimary : Theme.textPrimary.opacity(0.5))
                                    }
                                    .padding(.horizontal)

                                    Text(styleDescription)
                                        .font(.caption)
                                        .foregroundStyle(Theme.textPrimary.opacity(0.7))
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.white.opacity(0.7))
                                )
                                .padding(.horizontal)

                                // Duration slider
                                VStack(spacing: 12) {
                                    Text("Duration per Photo")
                                        .font(.headline)
                                        .foregroundStyle(Theme.textPrimary)

                                    HStack {
                                        Text("2s")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundStyle(Theme.textPrimary.opacity(0.6))

                                        Slider(value: $secondsPerPhoto, in: 2...8, step: 0.5)
                                            .tint(Theme.lavender)

                                        Text("8s")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundStyle(Theme.textPrimary.opacity(0.6))
                                    }
                                    .padding(.horizontal)

                                    Text(String(format: "%.1f seconds per photo", secondsPerPhoto))
                                        .font(.caption)
                                        .foregroundStyle(Theme.textPrimary.opacity(0.7))
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.white.opacity(0.7))
                                )
                                .padding(.horizontal)

                                // Total duration estimate
                                let photoCount = huntList.itemsArray.filter { $0.isFound }.count
                                let totalSeconds = Double(photoCount) * secondsPerPhoto + 8.0  // +4s title +4s end
                                let minutes = Int(totalSeconds) / 60
                                let seconds = Int(totalSeconds) % 60

                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundStyle(Theme.textPrimary)
                                    Text("Estimated length: \(minutes):\(String(format: "%02d", seconds))")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Theme.textPrimary)
                                }
                                .padding(.top, 8)

                                Button {
                                    generateSlideshow()
                                } label: {
                                    Label("Generate Slideshow", systemImage: "sparkles")
                                        .font(.headline)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Theme.lavender)
                                .padding(.horizontal, 40)
                                .padding(.top, 20)
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Slideshow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.lavenderLight, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Theme.lavender)
                }
            }
        }
    }

    private var styleDescription: String {
        if polaroidPercentage >= 0.95 {
            return "All polaroid frames"
        } else if polaroidPercentage <= 0.05 {
            return "All cinematic with Ken Burns effects"
        } else {
            let polaroidPct = Int(polaroidPercentage * 100)
            return "\(polaroidPct)% polaroid, \(100 - polaroidPct)% cinematic"
        }
    }

    private func generateSlideshow() {
        generationStarted = true
        let foundItems = huntList.itemsArray.filter { $0.isFound }

        let slideItems: [SlideshowGenerator.SlideItem] = foundItems.compactMap { item in
            guard let photoData = item.photoData,
                  let image = UIImage(data: photoData) else {
                return nil
            }

            return SlideshowGenerator.SlideItem(
                image: image,
                caption: item.name ?? "Found item",
                date: item.foundAt,
                location: nil // Could add reverse geocoding later
            )
        }

        generator.generateSlideshow(
            huntName: huntList.name ?? "Photo Hunt",
            huntDescription: huntList.listDescription,
            items: slideItems,
            polaroidPercentage: polaroidPercentage,
            photoDuration: secondsPerPhoto
        ) { result in
            switch result {
            case .success(let url):
                // Set videoURL first - this triggers the "Saving to Photos" interstitial
                // because generationStarted is true and showPlayer is false
                videoURL = url
                saveToPhotos(url: url)
            case .failure:
                generationStarted = false // Reset so user can try again
            }
        }
    }

    private func saveToPhotos(url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                // No permission, just show player without saving
                DispatchQueue.main.async {
                    showPlayer = true
                }
                return
            }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    showPlayer = true
                }
                if success {
                    print("Video saved to Photos")
                } else if let error = error {
                    print("Error saving to Photos: \(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    SlideshowGeneratorView(huntList: {
        let context = PersistenceController.preview.container.viewContext
        let request: NSFetchRequest<HuntListEntity> = HuntListEntity.fetchRequest()
        return try! context.fetch(request).first!
    }())
}
