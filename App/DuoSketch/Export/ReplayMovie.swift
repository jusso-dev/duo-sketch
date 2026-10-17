import AVFoundation
import SwiftUI
import UniformTypeIdentifiers
import SketchCore

/// The drawing's replay as a short H.264 QuickTime movie, for the share menu.
/// Frames are rendered with `ImageRenderer` and written with `AVAssetWriter`,
/// all on the phone.
struct ReplayMovie: Transferable {
    let sketch: Sketch
    /// The on-screen canvas the drawing was made on.
    var canvasSize = CanvasSize(width: 1, height: 1)
    var theme = FrameTheme.eucalyptus
    /// Pixels on the longer side of the video.
    var longSide: Double = 720
    var framesPerSecond = 30
    var duration = ReplayTimeline.duration
    /// Seconds the finished drawing stays on screen after the replay.
    var hold = 1.0
    var averageBitRate = 2_000_000

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .quickTimeMovie) { movie in
            SentTransferredFile(try await movie.write())
        }
        .suggestedFileName("Duo Sketch replay.mov")
    }

    enum MovieError: Error {
        case cannotStart
        case frameFailed
        case writeFailed
    }

    /// Video size in pixels: the drawing's shape at `longSide`, rounded to even
    /// numbers as H.264 wants.
    var pixelSize: (width: Int, height: Int) {
        let size = sketch.frame(in: canvasSize).size.scaled(toLongSide: longSide)
        func even(_ v: Double) -> Int { max(2, Int((v / 2).rounded()) * 2) }
        return (even(size.width), even(size.height))
    }

    var frameCount: Int { Int(((duration + hold) * Double(framesPerSecond)).rounded()) }

    /// Writes the movie to a new file in the temporary directory and returns it.
    @MainActor
    func write() async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Duo Sketch replay \(UUID().uuidString.prefix(8)).mov")
        let (width, height) = pixelSize
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: averageBitRate],
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? MovieError.cannotStart }
        writer.startSession(atSourceTime: .zero)

        let timeline = ReplayTimeline(sketch)
        for index in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(5))
            }
            let elapsed = Double(index) / Double(framesPerSecond)
            let frame = timeline.frame(at: ReplayTimeline.progress(atElapsed: elapsed, duration: duration))
            guard let image = render(frame, width: width, height: height),
                  let pool = adaptor.pixelBufferPool,
                  let buffer = ReplayMovie.pixelBuffer(from: image, pool: pool, width: width, height: height),
                  adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(index), timescale: CMTimeScale(framesPerSecond)))
            else {
                writer.cancelWriting()
                throw writer.error ?? MovieError.frameFailed
            }
        }
        input.markAsFinished()
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            writer.finishWriting { done.resume() }
        }
        guard writer.status == .completed else { throw writer.error ?? MovieError.writeFailed }
        return url
    }

    @MainActor
    private func render(_ frame: Sketch, width: Int, height: Int) -> CGImage? {
        let renderer = ImageRenderer(content: CanvasView(sketch: frame)
            .frame(width: CGFloat(width), height: CGFloat(height))
            .environment(\.frameTheme, theme))
        renderer.scale = 1
        return renderer.cgImage
    }

    private static func pixelBuffer(from image: CGImage, pool: CVPixelBufferPool, width: Int, height: Int) -> CVPixelBuffer? {
        var made: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &made) == kCVReturnSuccess, let buffer = made else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }
}
