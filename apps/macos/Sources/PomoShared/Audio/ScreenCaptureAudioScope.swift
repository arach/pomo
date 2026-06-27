import AVFoundation
import CoreMedia
import CoreGraphics
import Foundation
import ScreenCaptureKit

final class ScreenCaptureAudioScope: NSObject {
    static let sourceName = "screenCapture"

    private static let sampleRate = 48_000
    private static let channels = 2
    private static let analysisSize = 2048
    private static let ringSize = 16384
    private static let frameInterval = 1.0 / 30.0
    private static let minBandFrequency = 45.0
    private static let maxBandFrequency = 18_000.0
    private static let hannWindow: [Double] = {
        (0..<analysisSize).map { index in
            0.5 - 0.5 * cos(2.0 * Double.pi * Double(index) / Double(analysisSize - 1))
        }
    }()

    private let sampleQueue = DispatchQueue(label: "dev.pomo.sck-audio-scope.samples", qos: .userInitiated)
    private let onFrame: (AudioScopeFrame) -> Void
    private let onError: (String?) -> Void
    private let onLog: (String) -> Void

    private var stream: SCStream?
    private var isStarting = false
    private(set) var isRunning = false
    var isActive: Bool { isStarting || isRunning }
    private var startToken = 0

    private var ring = [Float](repeating: 0, count: ringSize)
    private var writeIndex = 0
    private var availableSamples = 0
    private var lastFrameHostTime = 0.0
    private var lastSampleHostTime = 0.0
    private var emittedFrameCount = 0
    private var sampleBufferCount = 0
    private var noSamplesWork: DispatchWorkItem?
    private var frameTimer: DispatchSourceTimer?
    private var smoothedBands = [Double](repeating: 0, count: 24)
    private var smoothedWaveform = [Double](repeating: 0, count: 32)
    private var smoothedRMS = 0.0
    private var smoothedPeak = 0.0

    init(onFrame: @escaping (AudioScopeFrame) -> Void, onError: @escaping (String?) -> Void, onLog: @escaping (String) -> Void) {
        self.onFrame = onFrame
        self.onError = onError
        self.onLog = onLog
        super.init()
    }

    func start() {
        guard !isRunning, !isStarting else { return }

        isStarting = true
        startToken += 1
        let token = startToken
        onLog("screen capture audio scope loading shareable content")
        loadShareableContent { [weak self] content, error in
            guard let self else { return }
            guard self.startToken == token else { return }
            if let content {
                self.start(with: content, token: token)
            } else {
                self.finishStart(error: error?.localizedDescription ?? "screen capture content unavailable")
            }
        }
    }

    func stop() {
        startToken += 1
        isStarting = false
        isRunning = false
        noSamplesWork?.cancel()
        noSamplesWork = nil
        resetAnalysis()
        guard let stream else { return }
        self.stream = nil
        stream.stopCapture { _ in }
    }

    private func loadShareableContent(_ completion: @escaping (SCShareableContent?, Error?) -> Void) {
        SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true, completionHandler: completion)
    }

    private func start(with content: SCShareableContent, token: Int) {
        guard startToken == token else { return }
        guard let display = bestDisplay(from: content) else {
            finishStart(error: "screen capture display unavailable")
            return
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])

        let configuration = SCStreamConfiguration()
        configuration.width = 2
        configuration.height = 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        configuration.queueDepth = 3
        configuration.showsCursor = false
        configuration.capturesAudio = true
        configuration.sampleRate = Self.sampleRate
        configuration.channelCount = Self.channels
        configuration.excludesCurrentProcessAudio = false

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        do {
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: sampleQueue)
        } catch {
            finishStart(error: error.localizedDescription)
            return
        }

        self.stream = stream
        onLog("screen capture audio scope starting stream")
        stream.startCapture { [weak self] error in
            guard let self else { return }
            guard self.startToken == token else {
                stream.stopCapture { _ in }
                return
            }
            if let error {
                self.finishStart(error: error.localizedDescription)
            } else {
                self.isStarting = false
                self.isRunning = true
                ScreenCaptureAudioPermission.recordSuccessfulAccess()
                Task { @MainActor in
                    ScreenCaptureAudioPermissionChecker.shared.noteSuccessfulAccess(reason: "stream started")
                }
                self.startFrameTimer(token: token)
                self.scheduleNoSamplesTimeout(token: token)
                self.onLog("screen capture audio scope started")
                self.onError(nil)
            }
        }
    }

    private func finishStart(error: String) {
        if ScreenCaptureAudioPermission.isPermissionError(error) {
            ScreenCaptureAudioPermission.clearCachedAccess()
        }
        isStarting = false
        isRunning = false
        stream = nil
        onError("screen capture audio unavailable: \(error)")
    }

    private func scheduleNoSamplesTimeout(token: Int) {
        noSamplesWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.startToken == token, self.isRunning, self.sampleBufferCount == 0 else { return }
            self.onLog("screen capture audio scope produced no samples; stopping stream")
            self.onError("screen capture audio produced no samples")
            self.stop()
        }
        noSamplesWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    private func bestDisplay(from content: SCShareableContent) -> SCDisplay? {
        let mainID = CGMainDisplayID()
        return content.displays.first(where: { $0.displayID == mainID }) ?? content.displays.first
    }

    private func resetAnalysis() {
        sampleQueue.async { [weak self] in
            guard let self else { return }
            self.ring = [Float](repeating: 0, count: Self.ringSize)
            self.writeIndex = 0
            self.availableSamples = 0
            self.lastFrameHostTime = 0
            self.lastSampleHostTime = 0
            self.emittedFrameCount = 0
            self.sampleBufferCount = 0
            self.frameTimer?.cancel()
            self.frameTimer = nil
            self.smoothedBands = [Double](repeating: 0, count: 24)
            self.smoothedWaveform = [Double](repeating: 0, count: 32)
            self.smoothedRMS = 0
            self.smoothedPeak = 0
        }
    }

    private func startFrameTimer(token: Int) {
        sampleQueue.async { [weak self] in
            guard let self, self.startToken == token else { return }
            self.frameTimer?.cancel()
            let timer = DispatchSource.makeTimerSource(queue: self.sampleQueue)
            timer.schedule(deadline: .now(), repeating: Self.frameInterval, leeway: .milliseconds(8))
            timer.setEventHandler { [weak self] in
                guard let self, self.startToken == token, self.isRunning else { return }
                self.maybeEmitFrame()
            }
            self.frameTimer = timer
            timer.resume()
        }
    }

    private func append(_ samples: [Float]) {
        for sample in samples {
            ring[writeIndex] = max(-1, min(1, sample))
            writeIndex = (writeIndex + 1) % Self.ringSize
            availableSamples = min(Self.ringSize, availableSamples + 1)
        }
        lastSampleHostTime = ProcessInfo.processInfo.systemUptime
    }

    private func maybeEmitFrame() {
        guard availableSamples >= Self.analysisSize else { return }
        let hostTime = ProcessInfo.processInfo.systemUptime
        guard lastSampleHostTime > 0, hostTime - lastSampleHostTime <= 1.25 else { return }
        guard hostTime - lastFrameHostTime >= Self.frameInterval else { return }
        lastFrameHostTime = hostTime

        let samples = recentSamples(count: Self.analysisSize)
        let waveform = smoothSigned(compactWaveform(samples, count: 32), previous: &smoothedWaveform)
        let bands = smoothUnsigned(spectrumBands(samples, count: 24), previous: &smoothedBands, attack: 0.38, release: 0.16)
        let rawRMS = sqrt(samples.reduce(0.0) { $0 + Double($1 * $1) } / Double(samples.count))
        let rawPeak = samples.map { abs(Double($0)) }.max() ?? 0
        let rms = smoothValue(rawRMS, previous: &smoothedRMS, attack: 0.45, release: 0.18)
        let peak = smoothValue(rawPeak, previous: &smoothedPeak, attack: 0.55, release: 0.22)
        emittedFrameCount += 1
        if emittedFrameCount == 1 {
            onLog("screen capture audio scope emitted first frame")
        }

        onFrame(
            AudioScopeFrame(
                source: Self.sourceName,
                hostTime: hostTime,
                mediaTime: 0,
                duration: 0,
                playbackRate: 1,
                bands: bands,
                waveform: waveform,
                rms: clamp(rms, 0, 1),
                peak: clamp(peak, 0, 1),
                low: average(bands.prefix(6)),
                mid: average(bands.dropFirst(6).prefix(9)),
                high: average(bands.dropFirst(15))
            )
        )
    }

    private func recentSamples(count: Int) -> [Float] {
        let count = min(count, availableSamples)
        return (0..<count).map { offset in
            let index = (writeIndex - count + offset + Self.ringSize) % Self.ringSize
            return ring[index]
        }
    }

    private func compactWaveform(_ samples: [Float], count: Int) -> [Double] {
        guard !samples.isEmpty else { return Array(repeating: 0, count: count) }
        let step = Double(samples.count) / Double(count)
        return (0..<count).map { index in
            let source = min(samples.count - 1, Int(Double(index) * step))
            return clamp(Double(samples[source]), -1, 1)
        }
    }

    private func spectrumBands(_ samples: [Float], count: Int) -> [Double] {
        guard samples.count > 1 else { return Array(repeating: 0, count: count) }
        return (0..<count).map { band in
            let x = Double(band) / Double(max(1, count - 1))
            let frequency = logFrequency(at: x)
            let magnitude = goertzelMagnitude(samples, frequency: frequency)
            let perceptualLift = 1.0 + pow(x, 0.72) * 1.55
            return clamp(magnitude * 18.0 * perceptualLift, 0, 1)
        }
    }

    private func logFrequency(at normalized: Double) -> Double {
        let minLog = log(Self.minBandFrequency)
        let maxLog = log(min(Self.maxBandFrequency, Double(Self.sampleRate) * 0.48))
        return exp(minLog + (maxLog - minLog) * clamp(normalized, 0, 1))
    }

    private func goertzelMagnitude(_ samples: [Float], frequency: Double) -> Double {
        let sampleRate = Double(Self.sampleRate)
        let omega = 2.0 * Double.pi * frequency / sampleRate
        let coefficient = 2.0 * cos(omega)
        var q1 = 0.0
        var q2 = 0.0

        for index in samples.indices {
            let sample = Double(samples[index]) * Self.hannWindow[min(index, Self.hannWindow.count - 1)]
            let q0 = sample + coefficient * q1 - q2
            q2 = q1
            q1 = q0
        }

        let power = max(0, q1 * q1 + q2 * q2 - coefficient * q1 * q2)
        return sqrt(power) / Double(max(1, samples.count))
    }

    private func smoothUnsigned(_ values: [Double], previous: inout [Double], attack: Double, release: Double) -> [Double] {
        if previous.count != values.count {
            previous = Array(repeating: 0, count: values.count)
        }
        return values.enumerated().map { index, value in
            let oldValue = previous[index]
            let coefficient = value > oldValue ? attack : release
            let next = oldValue + (value - oldValue) * coefficient
            previous[index] = next
            return clamp(next, 0, 1)
        }
    }

    private func smoothSigned(_ values: [Double], previous: inout [Double]) -> [Double] {
        if previous.count != values.count {
            previous = Array(repeating: 0, count: values.count)
        }
        return values.enumerated().map { index, value in
            let oldValue = previous[index]
            let coefficient = abs(value) > abs(oldValue) ? 0.42 : 0.24
            let next = oldValue + (value - oldValue) * coefficient
            previous[index] = next
            return clamp(next, -1, 1)
        }
    }

    private func smoothValue(_ value: Double, previous: inout Double, attack: Double, release: Double) -> Double {
        let coefficient = value > previous ? attack : release
        previous += (value - previous) * coefficient
        return clamp(previous, 0, 1)
    }

    private func mix(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * clamp(t, 0, 1)
    }

    private func monoSamples(from sampleBuffer: CMSampleBuffer) -> [Float] {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        else { return [] }

        var asbd = streamDescription.pointee
        guard let format = AVAudioFormat(streamDescription: &asbd) else { return [] }
        let frameCount = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard frameCount > 0,
              let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        else { return [] }

        pcmBuffer.frameLength = frameCount
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(frameCount),
            into: pcmBuffer.mutableAudioBufferList
        )
        guard status == noErr else { return [] }

        let frames = Int(pcmBuffer.frameLength)
        let channelCount = max(1, Int(format.channelCount))

        if let channels = pcmBuffer.floatChannelData {
            return (0..<frames).map { frame in
                var total: Float = 0
                if format.isInterleaved {
                    for channel in 0..<channelCount {
                        total += channels[0][frame * channelCount + channel]
                    }
                } else {
                    for channel in 0..<channelCount {
                        total += channels[channel][frame]
                    }
                }
                return total / Float(channelCount)
            }
        }

        if let channels = pcmBuffer.int16ChannelData {
            return (0..<frames).map { frame in
                var total: Float = 0
                if format.isInterleaved {
                    for channel in 0..<channelCount {
                        total += Float(channels[0][frame * channelCount + channel]) / Float(Int16.max)
                    }
                } else {
                    for channel in 0..<channelCount {
                        total += Float(channels[channel][frame]) / Float(Int16.max)
                    }
                }
                return total / Float(channelCount)
            }
        }

        if let channels = pcmBuffer.int32ChannelData {
            return (0..<frames).map { frame in
                var total: Float = 0
                if format.isInterleaved {
                    for channel in 0..<channelCount {
                        total += Float(channels[0][frame * channelCount + channel]) / Float(Int32.max)
                    }
                } else {
                    for channel in 0..<channelCount {
                        total += Float(channels[channel][frame]) / Float(Int32.max)
                    }
                }
                return total / Float(channelCount)
            }
        }

        return []
    }

    private func average<S: Sequence>(_ values: S) -> Double where S.Element == Double {
        var total = 0.0
        var count = 0.0
        for value in values {
            total += value
            count += 1
        }
        return count > 0 ? total / count : 0
    }

    private func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
        min(max(value, minValue), maxValue)
    }
}

extension ScreenCaptureAudioScope: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid else { return }
        sampleBufferCount += 1
        if sampleBufferCount == 1 {
            ScreenCaptureAudioPermission.recordSuccessfulAccess()
            Task { @MainActor in
                ScreenCaptureAudioPermissionChecker.shared.noteSuccessfulAccess(reason: "first audio sample")
            }
            onLog("screen capture audio scope received first sample buffer")
        }
        let samples = monoSamples(from: sampleBuffer)
        guard !samples.isEmpty else { return }
        append(samples)
        maybeEmitFrame()
    }
}

extension ScreenCaptureAudioScope: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        isRunning = false
        isStarting = false
        resetAnalysis()
        onError("screen capture audio stopped: \(error.localizedDescription)")
    }
}
