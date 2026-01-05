import SwiftUI

struct PolaroidFrameView: View {
    let image: UIImage
    let caption: String
    let date: Date?
    let rotation: Double
    let photoSize: CGFloat

    init(image: UIImage, caption: String, date: Date? = nil, rotation: Double = 0, photoSize: CGFloat = 280) {
        self.image = image
        self.caption = caption
        self.date = date
        self.rotation = rotation
        self.photoSize = photoSize
    }

    var body: some View {
        let borderWidth = photoSize * 0.05  // 5% border
        let bottomPadding = photoSize * 0.18  // Space for caption
        let fontSize = photoSize * 0.07
        let dateFontSize = photoSize * 0.05

        VStack(spacing: 0) {
            // Photo area
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: photoSize, height: photoSize)
                .clipped()
                .padding(borderWidth)
                .background(Color.white)

            // Caption area
            VStack(spacing: 4) {
                Text(caption)
                    .font(.system(size: fontSize, weight: .medium, design: .serif))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if let date = date {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: dateFontSize, design: .serif))
                        .foregroundStyle(.gray)
                }
            }
            .frame(width: photoSize)
            .padding(.horizontal, borderWidth)
            .padding(.bottom, bottomPadding)
            .padding(.top, borderWidth)
            .background(Color.white)
        }
        .shadow(color: .black.opacity(0.4), radius: 15, x: 8, y: 8)
        .rotationEffect(.degrees(rotation))
    }
}

// Generate a frame as a UIImage for video composition
extension PolaroidFrameView {
    @MainActor
    static func renderToImage(
        image: UIImage,
        caption: String,
        date: Date?,
        rotation: Double,
        size: CGSize
    ) -> UIImage? {
        // Make the photo take up ~85% of the width, accounting for rotation
        let photoSize = size.width * 0.80

        let frameView = PolaroidFrameView(
            image: image,
            caption: caption,
            date: date,
            rotation: rotation,
            photoSize: photoSize
        )
        .frame(width: size.width, height: size.height)
        .background(Color.black)

        let renderer = ImageRenderer(content: frameView)
        renderer.scale = 1.0  // Render at target size
        return renderer.uiImage
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        PolaroidFrameView(
            image: UIImage(systemName: "photo")!,
            caption: "A beautiful butterfly",
            date: Date(),
            rotation: -5
        )
    }
}
