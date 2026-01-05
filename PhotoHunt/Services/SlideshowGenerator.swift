import AVFoundation
import UIKit
import CoreImage

/// Generates a video slideshow from hunt photos with Ken Burns effects and transitions
@MainActor
class SlideshowGenerator: ObservableObject {
    @Published var progress: Double = 0
    @Published var isGenerating = false
    @Published var errorMessage: String?

    // Video settings
    let videoSize = CGSize(width: 750, height: 1334) // iPhone 7 resolution
    let fps: Int32 = 24
    let photoDuration: Double = 4.0 // seconds per photo
    let transitionDuration: Double = 1.0 // fade transition duration
    let titleDuration: Double = 4.0
    let endDuration: Double = 4.0

    private var audioURL: URL?

    init(audioURL: URL? = nil) {
        self.audioURL = audioURL
    }

    struct SlideItem {
        let image: UIImage
        let caption: String
        let date: Date?
        let location: String?
    }

    func generateSlideshow(
        huntName: String,
        huntDescription: String?,
        items: [SlideItem],
        polaroidPercentage: Double = 0.67,
        photoDuration: Double = 4.0,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        isGenerating = true
        progress = 0
        errorMessage = nil

        Task {
            do {
                let url = try await createVideo(huntName: huntName, huntDescription: huntDescription, items: items, polaroidPercentage: polaroidPercentage, photoDuration: photoDuration)
                await MainActor.run {
                    self.isGenerating = false
                    self.progress = 1.0
                    completion(.success(url))
                }
            } catch {
                await MainActor.run {
                    self.isGenerating = false
                    self.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    private func createVideo(huntName: String, huntDescription: String?, items: [SlideItem], polaroidPercentage: Double, photoDuration: Double) async throws -> URL {
        await updateProgress(0.01) // Starting...

        // Output file
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("photohunt_\(UUID().uuidString).mp4")

        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)

        await updateProgress(0.02) // Setting up video writer...

        // Setup writer
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(videoSize.width),
            AVVideoHeightKey: Int(videoSize.height)
        ]

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: Int(videoSize.width),
                kCVPixelBufferHeightKey as String: Int(videoSize.height)
            ]
        )

        writer.add(videoInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        await updateProgress(0.03) // Preparing photos...

        var frameCount: Int64 = 0
        let totalFrames = calculateTotalFrames(itemCount: items.count, photoDuration: photoDuration)

        // Compute date range from photos
        let dates = items.compactMap { $0.date }
        let dateRange: (start: Date, end: Date)? = if let minDate = dates.min(), let maxDate = dates.max() {
            (start: minDate, end: maxDate)
        } else {
            nil
        }

        await updateProgress(0.05) // Rendering title card...

        // Generate title card frames (no fade-in so first frame isn't black for thumbnail)
        let photos = items.map { $0.image }
        if let titleImage = TitleCardView.renderToImage(
            title: huntName,
            subtitle: huntDescription,
            dateRange: dateRange,
            size: videoSize,
            photos: photos
        ) {
            frameCount = try await writeFrames(
                image: titleImage,
                duration: titleDuration,
                startFrame: frameCount,
                adaptor: adaptor,
                videoInput: videoInput,
                effect: .none
            )
            await updateProgress(0.10 + 0.90 * Double(frameCount) / Double(totalFrames))
        }

        // Generate photo frames with mixed styles based on polaroidPercentage
        // Pre-determine which slides are polaroid vs fullscreen
        let slideStyles: [SlideStyle] = items.indices.map { index in
            // Use deterministic but mixed distribution based on percentage
            let threshold = polaroidPercentage
            // Create a pseudo-random but consistent pattern
            let value = Double((index * 7 + 3) % 10) / 10.0
            return value < threshold ? .polaroid : .fullscreen
        }

        for (index, item) in items.enumerated() {
            let style = slideStyles[index]

            switch style {
            case .polaroid:
                // Polaroid frame - static, no Ken Burns
                let rotation = Double.random(in: -6...6)

                if let frameImage = PolaroidFrameView.renderToImage(
                    image: item.image,
                    caption: item.caption,
                    date: item.date,
                    rotation: rotation,
                    size: videoSize
                ) {
                    frameCount = try await writeFrames(
                        image: frameImage,
                        duration: photoDuration,
                        startFrame: frameCount,
                        adaptor: adaptor,
                        videoInput: videoInput,
                        effect: .none  // Static - no movement
                    )
                    await updateProgress(0.10 + 0.90 * Double(frameCount) / Double(totalFrames))
                }

            case .fullscreen:
                // Fullscreen with Ken Burns effect - text overlay stays static
                if let fullscreenImage = renderFullscreenPhoto(photo: item.image),
                   let textOverlay = renderTextOverlay(caption: item.caption, date: item.date) {
                    let effect: FrameEffect = [.zoomIn, .zoomOut, .panLeft, .panRight].randomElement()!

                    frameCount = try await writeFramesWithOverlay(
                        image: fullscreenImage,
                        overlay: textOverlay,
                        duration: photoDuration,
                        startFrame: frameCount,
                        adaptor: adaptor,
                        videoInput: videoInput,
                        effect: effect
                    )
                    await updateProgress(0.10 + 0.90 * Double(frameCount) / Double(totalFrames))
                }
            }
        }

        // Generate end card frames
        if let endImage = EndCardView.renderToImage(
            itemCount: items.count,
            huntName: huntName,
            size: videoSize,
            photos: photos
        ) {
            frameCount = try await writeFrames(
                image: endImage,
                duration: endDuration,
                startFrame: frameCount,
                adaptor: adaptor,
                videoInput: videoInput,
                effect: .fadeOut
            )
        }

        // Finish writing
        videoInput.markAsFinished()
        await writer.finishWriting()

        if writer.status == .failed {
            throw writer.error ?? NSError(domain: "SlideshowGenerator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
        }

        // Add audio if available
        if let audioURL = audioURL {
            let finalURL = try await addAudioTrack(to: outputURL, audioURL: audioURL)
            return finalURL
        }

        return outputURL
    }

    private func calculateTotalFrames(itemCount: Int, photoDuration: Double) -> Int64 {
        let titleFrames = Int64(titleDuration * Double(fps))
        let photoFrames = Int64(Double(itemCount) * photoDuration * Double(fps))
        let endFrames = Int64(endDuration * Double(fps))
        return titleFrames + photoFrames + endFrames
    }

    enum FrameEffect {
        case none
        case fadeIn
        case fadeOut
        case zoomIn
        case zoomOut
        case panLeft
        case panRight
    }

    enum SlideStyle {
        case polaroid      // Static polaroid frame, simple fade transition
        case fullscreen    // Full bleed image with Ken Burns effect
    }

    /// Render a fullscreen photo without overlay (for Ken Burns effect)
    private func renderFullscreenPhoto(photo: UIImage) -> UIImage? {
        let size = videoSize
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        // Black background
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        // Scale photo to fill (may crop)
        let photoAspect = photo.size.width / photo.size.height
        let videoAspect = size.width / size.height

        var drawRect: CGRect
        if photoAspect > videoAspect {
            // Photo is wider - fit height, crop width
            let drawHeight = size.height
            let drawWidth = drawHeight * photoAspect
            let x = (size.width - drawWidth) / 2
            drawRect = CGRect(x: x, y: 0, width: drawWidth, height: drawHeight)
        } else {
            // Photo is taller - fit width, crop height
            let drawWidth = size.width
            let drawHeight = drawWidth / photoAspect
            let y = (size.height - drawHeight) / 2
            drawRect = CGRect(x: 0, y: y, width: drawWidth, height: drawHeight)
        }

        photo.draw(in: drawRect)

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    /// Render text overlay (static, composited on top of Ken Burns frames)
    private func renderTextOverlay(caption: String, date: Date?) -> UIImage? {
        let size = videoSize
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)  // false = transparent background
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        // Draw translucent overlay at bottom - darker for better readability
        let overlayHeight: CGFloat = size.height * 0.18

        // Gradient from transparent to more opaque black
        let gradientColors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.85).cgColor]
        let gradientLocations: [CGFloat] = [0.0, 1.0]

        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: gradientColors as CFArray,
                                      locations: gradientLocations) {
            context.drawLinearGradient(gradient,
                                       start: CGPoint(x: 0, y: size.height - overlayHeight),
                                       end: CGPoint(x: 0, y: size.height),
                                       options: [])
        }

        // Draw caption text
        let captionFontSize = size.width * 0.055
        let dateFontSize = size.width * 0.035
        let padding = size.width * 0.05

        let captionFont = UIFont.systemFont(ofSize: captionFontSize, weight: .semibold)
        let captionAttributes: [NSAttributedString.Key: Any] = [
            .font: captionFont,
            .foregroundColor: UIColor.white
        ]

        let captionSize = caption.size(withAttributes: captionAttributes)
        let captionY = size.height - overlayHeight * 0.6
        let captionRect = CGRect(x: padding, y: captionY, width: size.width - padding * 2, height: captionSize.height)
        caption.draw(in: captionRect, withAttributes: captionAttributes)

        // Draw date if available
        if let date = date {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none
            let dateString = dateFormatter.string(from: date)

            let dateFont = UIFont.systemFont(ofSize: dateFontSize, weight: .regular)
            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: dateFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.8)
            ]

            let dateY = captionY + captionSize.height + 4
            let dateRect = CGRect(x: padding, y: dateY, width: size.width - padding * 2, height: dateFontSize * 1.5)
            dateString.draw(in: dateRect, withAttributes: dateAttributes)
        }

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    /// Composite the text overlay onto a photo frame
    private func compositeOverlay(_ overlay: CGImage, onto photo: CGImage) -> CGImage? {
        let width = photo.width
        let height = photo.height

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            return photo
        }

        let rect = CGRect(x: 0, y: 0, width: width, height: height)

        // Draw the photo
        context.draw(photo, in: rect)

        // Draw the overlay on top
        context.draw(overlay, in: rect)

        return context.makeImage()
    }

    private func writeFrames(
        image: UIImage,
        duration: Double,
        startFrame: Int64,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        videoInput: AVAssetWriterInput,
        effect: FrameEffect
    ) async throws -> Int64 {
        let frameCount = Int64(duration * Double(fps))
        var currentFrame = startFrame

        guard let cgImage = image.cgImage else {
            return currentFrame + frameCount
        }

        for i in 0..<frameCount {
            // Wait for input to be ready
            while !videoInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }

            let progress = Double(i) / Double(frameCount)

            // Apply effect to create modified image
            let modifiedImage = applyEffect(to: cgImage, effect: effect, progress: progress)

            if let pixelBuffer = createPixelBuffer(from: modifiedImage ?? cgImage) {
                let presentationTime = CMTime(value: currentFrame, timescale: fps)
                adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
            }

            currentFrame += 1
        }

        return currentFrame
    }

    /// Write frames with Ken Burns on image and static overlay composited on top
    private func writeFramesWithOverlay(
        image: UIImage,
        overlay: UIImage,
        duration: Double,
        startFrame: Int64,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        videoInput: AVAssetWriterInput,
        effect: FrameEffect
    ) async throws -> Int64 {
        let frameCount = Int64(duration * Double(fps))
        var currentFrame = startFrame

        guard let cgImage = image.cgImage,
              let overlayImage = overlay.cgImage else {
            return currentFrame + frameCount
        }

        for i in 0..<frameCount {
            // Wait for input to be ready
            while !videoInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }

            let progress = Double(i) / Double(frameCount)

            // Apply Ken Burns effect to photo only
            let modifiedPhoto = applyEffect(to: cgImage, effect: effect, progress: progress) ?? cgImage

            // Composite static overlay on top
            let finalImage = compositeOverlay(overlayImage, onto: modifiedPhoto) ?? modifiedPhoto

            if let pixelBuffer = createPixelBuffer(from: finalImage) {
                let presentationTime = CMTime(value: currentFrame, timescale: fps)
                adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
            }

            currentFrame += 1
        }

        return currentFrame
    }

    private func applyEffect(to image: CGImage, effect: FrameEffect, progress: Double) -> CGImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)

        var transform = CGAffineTransform.identity
        var alpha: CGFloat = 1.0

        switch effect {
        case .none:
            return image

        case .fadeIn:
            alpha = CGFloat(min(1.0, progress * 3)) // Fade in over first third

        case .fadeOut:
            alpha = CGFloat(max(0.0, 1.0 - (progress - 0.66) * 3)) // Fade out over last third

        case .zoomIn:
            let scale = 1.0 + (progress * 0.15) // Zoom from 100% to 115%
            let offsetX = (width * (scale - 1)) / 2
            let offsetY = (height * (scale - 1)) / 2
            transform = CGAffineTransform(translationX: -offsetX, y: -offsetY)
                .scaledBy(x: scale, y: scale)

        case .zoomOut:
            let scale = 1.15 - (progress * 0.15) // Zoom from 115% to 100%
            let offsetX = (width * (scale - 1)) / 2
            let offsetY = (height * (scale - 1)) / 2
            transform = CGAffineTransform(translationX: -offsetX, y: -offsetY)
                .scaledBy(x: scale, y: scale)

        case .panLeft:
            let panAmount = width * 0.1 * progress
            transform = CGAffineTransform(translationX: panAmount, y: 0)
                .scaledBy(x: 1.1, y: 1.1)

        case .panRight:
            let panAmount = width * 0.1 * progress
            transform = CGAffineTransform(translationX: -panAmount, y: 0)
                .scaledBy(x: 1.1, y: 1.1)
        }

        // Create new context and apply transform
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(width),
            height: Int(height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            return image
        }

        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        context.setAlpha(alpha)
        context.concatenate(transform)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return context.makeImage()
    }

    private func createPixelBuffer(from cgImage: CGImage) -> CVPixelBuffer? {
        let width = cgImage.width
        let height = cgImage.height

        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        return buffer
    }

    private func addAudioTrack(to videoURL: URL, audioURL: URL) async throws -> URL {
        let composition = AVMutableComposition()

        // Add video track
        let videoAsset = AVAsset(url: videoURL)
        guard let videoTrack = try await videoAsset.loadTracks(withMediaType: .video).first,
              let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
              ) else {
            return videoURL
        }

        let videoDuration = try await videoAsset.load(.duration)
        try compositionVideoTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: videoDuration),
            of: videoTrack,
            at: .zero
        )

        // Add audio track
        let audioAsset = AVAsset(url: audioURL)
        if let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first,
           let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            // Loop audio if needed to match video duration
            let audioDuration = try await audioAsset.load(.duration)
            var currentTime = CMTime.zero

            while currentTime < videoDuration {
                let remainingTime = CMTimeSubtract(videoDuration, currentTime)
                let insertDuration = CMTimeMinimum(audioDuration, remainingTime)

                try compositionAudioTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: insertDuration),
                    of: audioTrack,
                    at: currentTime
                )

                currentTime = CMTimeAdd(currentTime, insertDuration)
            }
        }

        // Export
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("photohunt_final_\(UUID().uuidString).mp4")

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            return videoURL
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4

        await exportSession.export()

        if exportSession.status == .completed {
            try? FileManager.default.removeItem(at: videoURL)
            return outputURL
        }

        return videoURL
    }

    private func updateProgress(_ value: Double) async {
        await MainActor.run {
            self.progress = value
        }
    }
}
