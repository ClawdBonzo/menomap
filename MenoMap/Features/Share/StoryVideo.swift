import AVFoundation
import SwiftUI
import MenoCore

/// Animated 9:16 story ("My month in heat"), rendered frame by frame on device with the share-card palette.
/// Numbers only, like the still cards. Output: 1080×1920 H.264, 6 seconds.
struct StoryVideoFrame: View {
    let stats: SurgeStats
    let title: String
    let headline: String
    let t: Double

    private func phase(_ start: Double, _ end: Double) -> Double {
        min(max((t - start) / (end - start), 0), 1)
    }

    var body: some View {
        let fill = phase(0.10, 0.55)
        let count = phase(0.30, 0.70)
        let clock = phase(0.50, 0.80)
        let outro = phase(0.78, 0.92)
        ZStack {
            CardPalette.ground
            ContourBackdrop().opacity(0.5 * phase(0, 0.2))
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("MenoMap").font(.system(size: 15, weight: .semibold, design: .serif))
                    Spacer()
                    Text(Copy.caps(title)).font(.system(size: 11, weight: .semibold)).tracking(1)
                }
                .foregroundStyle(CardPalette.ink)
                .opacity(phase(0, 0.12))

                Text("\(Int((Double(stats.total) * easeOut(count)).rounded()))")
                    .font(.system(size: 92, weight: .semibold, design: .serif).monospacedDigit())
                    .foregroundStyle(CardPalette.ink)
                Text(headline)
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundStyle(CardPalette.ink)
                    .opacity(phase(0.35, 0.5))

                let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
                LazyVGrid(columns: cols, spacing: 4) {
                    ForEach(Array(stats.days.enumerated()), id: \.offset) { i, d in
                        let shown = Double(i) / Double(max(stats.days.count, 1)) < fill
                        RoundedRectangle(cornerRadius: 5)
                            .fill(CardPalette.heat(shown ? d.level : 0))
                            .aspectRatio(1, contentMode: .fit)
                            .scaleEffect(shown ? 1 : 0.7)
                    }
                }

                HStack(alignment: .center, spacing: 16) {
                    SurgeClock(histogram: stats.hourHistogram.map { Int(Double($0) * easeOut(clock)) },
                               ember: CardPalette.ember, hairline: CardPalette.hair, labelColor: CardPalette.ink2)
                        .frame(width: 120, height: 120)
                        .opacity(phase(0.48, 0.58))
                    VStack(alignment: .leading, spacing: 6) {
                        if let p = stats.peakTime {
                            Text("Peak \(Copy.clock(p))").font(.system(size: 17, weight: .semibold, design: .serif))
                        }
                        if stats.longestCalmStretch > 0 {
                            Text("Calm stretch \(stats.longestCalmStretch)d").font(.system(size: 15, weight: .medium))
                        }
                    }
                    .foregroundStyle(CardPalette.ink)
                    .opacity(phase(0.65, 0.78))
                }
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Logged with MenoMap").font(.system(size: 13, weight: .semibold))
                    Text("gwlabs.app/menomap").font(.system(size: 12))
                }
                .foregroundStyle(CardPalette.ink)
                .opacity(outro)
            }
            .padding(28)
        }
        .frame(width: 360, height: 640)
        .environment(\.colorScheme, .light)
    }

    private func easeOut(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
}

enum StoryVideoExporter {
    static let fps: Int32 = 30
    static let seconds = 6.0

    /// Renders on the main actor (ImageRenderer requirement), yielding between frames so the UI stays live.
    @MainActor
    static func export(stats: SurgeStats, title: String, headline: String, progress: @escaping (Double) -> Void) async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "MenoMap-\(DayKey.today()).mp4")
        try? FileManager.default.removeItem(at: url)
        let size = CGSize(width: 1080, height: 1920)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width, AVVideoHeightKey: size.height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 6_000_000],
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: size.width, kCVPixelBufferHeightKey as String: size.height,
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let total = Int(Double(fps) * seconds)
        for i in 0..<total {
            let t = Double(i) / Double(total - 1)
            let r = ImageRenderer(content: StoryVideoFrame(stats: stats, title: title, headline: headline, t: t))
            r.scale = 3
            guard let cg = r.cgImage, let buffer = pixelBuffer(from: cg, size: size, pool: adaptor.pixelBufferPool) else { continue }
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: fps))
            if i % 6 == 0 {
                progress(Double(i) / Double(total))
                await Task.yield()
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        progress(1)
        if writer.status != .completed { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        return url
    }

    private static func pixelBuffer(from image: CGImage, size: CGSize, pool: CVPixelBufferPool?) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        if let pool { CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) }
        guard let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: Int(size.width), height: Int(size.height),
                                  bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { return nil }
        ctx.draw(image, in: CGRect(origin: .zero, size: size))
        return buffer
    }
}

/// "Make a video" button with progress and a share link when done.
struct StoryVideoButton: View {
    let stats: SurgeStats
    let title: String
    let headline: String
    @State private var progress: Double?
    @State private var url: URL?
    @State private var failed = false

    var body: some View {
        VStack(spacing: 8) {
            if let url {
                ShareLink(item: url, preview: SharePreview("MenoMap", icon: Image(systemName: "film"))) {
                    Label("Share video", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.menoPrimary)
            } else if let progress {
                ProgressView(value: progress) { Text("Making your video…").font(.subheadline) }
                    .tint(MenoTheme.teal)
            } else {
                Button {
                    Task {
                        progress = 0
                        do {
                            url = try await StoryVideoExporter.export(stats: stats, title: title, headline: headline) { progress = $0 }
                        } catch {
                            failed = true
                        }
                        progress = nil
                    }
                } label: { Label("Make a video for Stories and Reels", systemImage: "film") }
                .buttonStyle(.menoSecondary)
            }
            if failed { Text("Couldn't make the video. Try again.").font(.caption).foregroundStyle(MenoTheme.inkSecondary) }
        }
    }
}
