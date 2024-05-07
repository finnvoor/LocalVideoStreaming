import Combine
import CoreMedia
import Foundation
import MultipeerConnectivity
import RealtimeStreaming
import Transcoding

// MARK: - Networking

@Observable final class Networking: NSObject {
    // MARK: Lifecycle

    override init() {
        super.init()

        videoEncoderTask = Task {
            for await data in videoEncoderAnnexBAdaptor.annexBData {
                try? await realtimeStreaming.send(data: data, messageType: .hevcData)
            }
        }

        videoDecoderTask = Task {
            for await decodedSampleBuffer in videoDecoder.decodedSampleBuffers {
                if let pixelBuffer = decodedSampleBuffer.imageBuffer {
                    for continuation in pixelBufferContinuations.values {
                        continuation.yield(pixelBuffer)
                    }
                }
            }
        }

        receivedMessageTask = Task {
            for await (data, _) in realtimeStreaming.receivedMessages {
                videoDecoderAnnexBAdaptor.decode(data)
            }
        }
    }

    // MARK: Internal

    var isConnected: Bool { realtimeStreaming.isConnected }

    @ObservationIgnored var pixelBuffers: AsyncStream<CVPixelBuffer> {
        .init { continuation in
            let id = UUID()
            pixelBufferContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                self?.pixelBufferContinuations[id] = nil
            }
        }
    }

    func attemptToReconnect() {
        realtimeStreaming.attemptToReconnect()
    }

    func disconnect() {
        realtimeStreaming.disconnect()
    }

    func setBitrate(_ bitrate: Int) {
        videoEncoder.config.averageBitRate = bitrate
    }

    func setExpectedFrameRate(_ frameRate: Int) {
        videoEncoder.config.expectedFrameRate = frameRate
    }

    func send(_ pixelBuffer: CVPixelBuffer) {
        guard isConnected else { return }
        videoEncoder.encode(pixelBuffer)
    }

    func startBrowsing() {
        realtimeStreaming.startBrowsing(for: Constants.bonjourServiceType)
    }

    func startAdvertising() {
        realtimeStreaming.startListening(for: Constants.bonjourServiceType)
    }

    func stopAdvertising() {
        realtimeStreaming.stopListening()
    }

    func resetEncoder() {
        videoEncoder.invalidate()
    }

    // MARK: Private

    private let realtimeStreaming = RealtimeStreaming()

    private var videoEncoderTask: Task<Void, Never>?
    private var videoDecoderTask: Task<Void, Never>?
    private var receivedMessageTask: Task<Void, Never>?

    @ObservationIgnored private lazy var videoEncoder = VideoEncoder(config: .ultraLowLatency)
    @ObservationIgnored private lazy var videoEncoderAnnexBAdaptor = VideoEncoderAnnexBAdaptor(
        videoEncoder: videoEncoder
    )
    @ObservationIgnored private lazy var videoDecoder = VideoDecoder(config: .init())
    @ObservationIgnored private lazy var videoDecoderAnnexBAdaptor = VideoDecoderAnnexBAdaptor(
        videoDecoder: videoDecoder,
        codec: .hevc
    )

    @ObservationIgnored private var pixelBufferContinuations: [UUID: AsyncStream<CVPixelBuffer>.Continuation] = [:]
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
}
