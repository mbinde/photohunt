import SwiftUI

struct TitleCardView: View {
    let title: String
    let subtitle: String?
    let dateRange: (start: Date, end: Date)?
    let size: CGSize?
    let photos: [UIImage]

    init(title: String, subtitle: String?, dateRange: (start: Date, end: Date)?, size: CGSize? = nil, photos: [UIImage] = []) {
        self.title = title
        self.subtitle = subtitle
        self.dateRange = dateRange
        self.size = size
        self.photos = photos
    }

    private var dateString: String? {
        guard let range = dateRange else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let calendar = Calendar.current
        if calendar.isDate(range.start, inSameDayAs: range.end) {
            // Same day
            return formatter.string(from: range.start)
        } else {
            // Date range
            return "\(formatter.string(from: range.start)) – \(formatter.string(from: range.end))"
        }
    }

    var body: some View {
        let scale = (size?.width ?? 375) / 375  // Scale relative to standard width
        let miniSize = 70 * scale  // Size of mini polaroids

        // Adaptive title font size based on length
        let baseTitleSize: CGFloat = title.count > 20 ? 36 : (title.count > 12 ? 44 : 56)

        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Theme.lavender.opacity(0.8), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )

            // Scattered polaroid border
            if !photos.isEmpty {
                PolaroidBorder(photos: photos, miniSize: miniSize, scale: scale)
            }

            // Main content
            VStack(spacing: 20 * scale) {
                Spacer()
                Spacer()

                Text(title)
                    .font(.system(size: baseTitleSize * scale, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                    .padding(.horizontal, 100 * scale)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 22 * scale, weight: .medium, design: .serif))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                        .lineLimit(3)
                        .padding(.horizontal, 100 * scale)
                }

                if let dateStr = dateString {
                    Text(dateStr)
                        .font(.system(size: 14 * scale, design: .serif))
                        .foregroundStyle(Theme.lavenderLight)
                        .padding(.top, 4 * scale)
                }

                Spacer()

                // App branding at bottom (above the polaroid border)
                Image("photohunt-transparent")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 20 * scale)

                Spacer()
                Spacer()
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Mini polaroid photos scattered around the border
struct PolaroidBorder: View {
    let photos: [UIImage]
    let miniSize: CGFloat
    let scale: CGFloat

    // Predefined positions around the border (relative to center, in a rough rectangle)
    var positions: [(x: CGFloat, y: CGFloat, rotation: Double)] {
        [
            // Top edge
            (-0.35, -0.42, -15),
            (-0.12, -0.44, 8),
            (0.12, -0.43, -5),
            (0.35, -0.41, 12),
            // Right edge
            (0.42, -0.25, -20),
            (0.44, 0.0, 15),
            (0.42, 0.25, -8),
            // Bottom edge
            (0.35, 0.42, 10),
            (0.12, 0.44, -12),
            (-0.12, 0.43, 18),
            (-0.35, 0.41, -6),
            // Left edge
            (-0.42, 0.25, 14),
            (-0.44, 0.0, -18),
            (-0.42, -0.25, 8),
        ]
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let centerX = width / 2
            let centerY = height / 2

            ForEach(0..<min(photos.count, positions.count), id: \.self) { index in
                let pos = positions[index]
                let photo = photos[index]

                MiniPolaroid(image: photo, size: miniSize)
                    .rotationEffect(.degrees(pos.rotation))
                    .position(
                        x: centerX + pos.x * width,
                        y: centerY + pos.y * height
                    )
            }
        }
    }
}

/// A tiny polaroid frame for the border decoration
struct MiniPolaroid: View {
    let image: UIImage
    let size: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipped()
                .padding(size * 0.06)
                .background(Color.white)

            // Bottom polaroid strip
            Rectangle()
                .fill(Color.white)
                .frame(width: size + size * 0.12, height: size * 0.2)
        }
        .shadow(color: .black.opacity(0.4), radius: 4, x: 2, y: 2)
    }
}

struct EndCardView: View {
    let itemCount: Int
    let huntName: String
    let size: CGSize?
    let photos: [UIImage]

    init(itemCount: Int, huntName: String, size: CGSize? = nil, photos: [UIImage] = []) {
        self.itemCount = itemCount
        self.huntName = huntName
        self.size = size
        self.photos = photos
    }

    var body: some View {
        let scale = (size?.width ?? 375) / 375
        let miniSize = 70 * scale

        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.black, Theme.lavender.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Scattered polaroid border
            if !photos.isEmpty {
                PolaroidBorder(photos: photos, miniSize: miniSize, scale: scale)
            }

            // Main content
            VStack(spacing: 20 * scale) {
                Spacer()
                Spacer()

                Image(systemName: "sparkles")
                    .font(.system(size: 60 * scale))
                    .foregroundStyle(Theme.accentPink)

                Text("The End!")
                    .font(.system(size: 48 * scale, weight: .bold, design: .serif))
                    .foregroundStyle(.white)

                Text("\(itemCount) items found")
                    .font(.system(size: 24 * scale, weight: .medium, design: .serif))
                    .foregroundStyle(.white.opacity(0.8))

                Text(huntName)
                    .font(.system(size: 20 * scale, design: .serif))
                    .foregroundStyle(Theme.lavenderLight)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 100 * scale)
                    .padding(.top, 8 * scale)

                Spacer()

                // App branding at bottom (above the polaroid border)
                Image("photohunt-transparent")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 20 * scale)

                Spacer()
                Spacer()
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Render to UIImage for video composition
extension TitleCardView {
    @MainActor
    static func renderToImage(title: String, subtitle: String?, dateRange: (start: Date, end: Date)?, size: CGSize, photos: [UIImage] = []) -> UIImage? {
        let view = TitleCardView(title: title, subtitle: subtitle, dateRange: dateRange, size: size, photos: photos)
            .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0  // Render at target size
        return renderer.uiImage
    }
}

extension EndCardView {
    @MainActor
    static func renderToImage(itemCount: Int, huntName: String, size: CGSize, photos: [UIImage] = []) -> UIImage? {
        let view = EndCardView(itemCount: itemCount, huntName: huntName, size: size, photos: photos)
            .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0  // Render at target size
        return renderer.uiImage
    }
}

#Preview("Title Card") {
    TitleCardView(
        title: "Backyard Adventure",
        subtitle: "A Photo Hunt Journey",
        dateRange: (start: Date().addingTimeInterval(-86400 * 3), end: Date()),
        size: nil
    )
}

#Preview("End Card") {
    EndCardView(itemCount: 20, huntName: "Backyard Adventure", size: nil)
}
