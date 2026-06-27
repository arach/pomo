import AVFAudio
import CoreAudio
import Foundation

final class CoreAudioTapAudioScope {
    static let sourceName = "coreAudioTap"

    private static let defaultSampleRate = 48_000.0
    private static let analysisSize = 2048
    private static let ringSize = 16384
    private static let defaultFrameInterval = 1.0 / 30.0
    private static let minBandFrequency = 45.0
    private static let maxBandFrequency = 18_000.0
    private static let hannWindow: [Double] = {
        (0..<analysisSize).map { index in
            0.5 - 0.5 * cos(2.0 * Double.pi * Double(index) / Double(analysisSize - 1))
        }
    }()

    private let sampleQueue = DispatchQueue(label: "dev.pomo.core-audio-tap-scope.samples", qos: .userInitiated)
    private let onFrame: (AudioScopeFrame) -> Void
    private let onError: (String?) -> Void
    private let onLog: (String) -> Void

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var streamFormat = AudioStreamBasicDescription()
    private var sampleRate = defaultSampleRate
    private var frameInterval = defaultFrameInterval
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
    }

    deinit {
        stop()
    }

    func start() {
        guard !isRunning, !isStarting else { return }
        guard #available(macOS 14.2, *) else {
            onError("core audio tap requires macOS 14.2 or newer")
            return
        }

        isStarting = true
        startToken += 1
        let token = startToken

        sampleQueue.async { [weak self] in
            guard let self else { return }
            self.startOnSampleQueue(token: token)
        }
    }

    func stop() {
        startToken += 1
        isStarting = false
        isRunning = false
        noSamplesWork?.cancel()
        noSamplesWork = nil
        sampleQueue.async { [weak self] in
            self?.stopOnSampleQueue(resetAnalysis: true)
        }
    }

    func setFrameInterval(milliseconds: Int) {
        let interval = Double(max(50, min(500, milliseconds))) / 1000.0
        sampleQueue.async { [weak self] in
            guard let self else { return }
            guard abs(self.frameInterval - interval) > 0.001 else { return }
            self.frameInterval = interval
            if self.isRunning {
                self.startFrameTimer(token: self.startToken)
            }
        }
    }

    @available(macOS 14.2, *)
    private func startOnSampleQueue(token: Int) {
        guard startToken == token else { return }
        stopOnSampleQueue(resetAnalysis: true)

        onLog("core audio tap scope creating process tap")
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.name = "Pomo Amp Visualizer Audio Tap"
        description.uuid = UUID()
        description.isPrivate = true
        description.muteBehavior = .unmuted

        var newTapID = AudioObjectID(kAudioObjectUnknown)
        var status = AudioHardwareCreateProcessTap(description, &newTapID)
        guard status == noErr else {
            finishStart(error: "create process tap failed: \(Self.describe(status))")
            return
        }
        tapID = newTapID
        streamFormat = readTapFormat(newTapID) ?? AudioStreamBasicDescription()
        sampleRate = streamFormat.mSampleRate > 0 ? streamFormat.mSampleRate : Self.defaultSampleRate

        let aggregateUID = "dev.pomo.amp.audio-tap.\(UUID().uuidString)"
        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Pomo Amp Visualizer Audio Tap",
            kAudioAggregateDeviceUIDKey: aggregateUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceTapAutoStartKey: false,
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapUIDKey: description.uuid.uuidString,
                    kAudioSubTapDriftCompensationKey: true,
                    kAudioSubTapDriftCompensationQualityKey: kAudioAggregateDriftCompensationMediumQuality
                ]
            ]
        ]

        onLog("core audio tap scope creating aggregate device")
        var newAggregateID = AudioObjectID(kAudioObjectUnknown)
        status = AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &newAggregateID)
        guard status == noErr else {
            finishStart(error: "create aggregate device failed: \(Self.describe(status))")
            return
        }
        aggregateDeviceID = newAggregateID

        var newIOProcID: AudioDeviceIOProcID?
        status = AudioDeviceCreateIOProcIDWithBlock(&newIOProcID, newAggregateID, sampleQueue) { [weak self] _, inputData, _, _, _ in
            self?.handleInput(inputData)
        }
        guard status == noErr, let newIOProcID else {
            finishStart(error: "create tap IOProc failed: \(Self.describe(status))")
            return
        }
        ioProcID = newIOProcID

        onLog("core audio tap scope starting aggregate device")
        status = AudioDeviceStart(newAggregateID, newIOProcID)
        guard status == noErr else {
            finishStart(error: "start tap aggregate failed: \(Self.describe(status))")
            return
        }

        isStarting = false
        isRunning = true
        startFrameTimer(token: token)
        scheduleNoSamplesTimeout(token: token)
        onLog("core audio tap scope started")
        onError(nil)
    }

    private func finishStart(error: String) {
        isStarting = false
        isRunning = false
        stopOnSampleQueue(resetAnalysis: true)
        onError("core audio tap unavailable: \(error)")
    }

    private func stopOnSampleQueue(resetAnalysis: Bool) {
        if aggregateDeviceID != AudioObjectID(kAudioObjectUnknown), let ioProcID {
            _ = AudioDeviceStop(aggregateDeviceID, ioProcID)
            _ = AudioDeviceDestroyIOProcID(aggregateDeviceID, ioProcID)
        }
        ioProcID = nil

        if aggregateDeviceID != AudioObjectID(kAudioObjectUnknown) {
            _ = AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
        }
        aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)

        if tapID != AudioObjectID(kAudioObjectUnknown) {
            if #available(macOS 14.2, *) {
                _ = AudioHardwareDestroyProcessTap(tapID)
            }
        }
        tapID = AudioObjectID(kAudioObjectUnknown)

        if resetAnalysis {
            ring = [Float](repeating: 0, count: Self.ringSize)
            writeIndex = 0
            availableSamples = 0
            lastFrameHostTime = 0
            lastSampleHostTime = 0
            emittedFrameCount = 0
            sampleBufferCount = 0
            frameTimer?.cancel()
            frameTimer = nil
            smoothedBands = [Double](repeating: 0, count: 24)
            smoothedWaveform = [Double](repeating: 0, count: 32)
            smoothedRMS = 0
            smoothedPeak = 0
        }
    }

    private func scheduleNoSamplesTimeout(token: Int) {
        noSamplesWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.startToken == token, self.isRunning, self.sampleBufferCount == 0 else { return }
            self.onLog("core audio tap scope produced no samples; stopping tap")
            self.onError("core audio tap produced no samples")
            self.stop()
        }
        noSamplesWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    private func readTapFormat(_ tapID: AudioObjectID) -> AudioStreamBasicDescription? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let status = AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &format)
        guard status == noErr else {
            onLog("core audio tap scope format unavailable: \(Self.describe(status))")
            return nil
        }
        return format
    }

    private func startFrameTimer(token: Int) {
        frameTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: sampleQueue)
        timer.schedule(deadline: .now(), repeating: frameInterval, leeway: .milliseconds(8))
        timer.setEventHandler { [weak self] in
            guard let self, self.startToken == token, self.isRunning else { return }
            self.maybeEmitFrame()
        }
        frameTimer = timer
        timer.resume()
    }

    private func handleInput(_ inputData: UnsafePointer<AudioBufferList>) {
        let samples = monoSamples(from: inputData)
        guard !samples.isEmpty else { return }
        sampleBufferCount += 1
        if sampleBufferCount == 1 {
            onLog("core audio tap scope received first audio buffer")
        }
        append(samples)
        maybeEmitFrame()
    }

    private func monoSamples(from inputData: UnsafePointer<AudioBufferList>) -> [Float] {
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inputData))
        guard !buffers.isEmpty else { return [] }

        if buffers.count == 1, let first = buffers.first {
            return monoSamples(from: first)
        }

        let floatBuffers = buffers.compactMap { buffer -> UnsafePointer<Float>? in
            guard let data = buffer.mData else { return nil }
            return UnsafeRawPointer(data).assumingMemoryBound(to: Float.self)
        }
        guard !floatBuffers.isEmpty else { return [] }

        let frameCount = buffers.map { Int($0.mDataByteSize) / MemoryLayout<Float>.size }.min() ?? 0
        guard frameCount > 0 else { return [] }

        return (0..<frameCount).map { frame in
            var total: Float = 0
            for channel in floatBuffers {
                total += channel[frame]
            }
            return total / Float(floatBuffers.count)
        }
    }

    private func monoSamples(from buffer: AudioBuffer) -> [Float] {
        guard let data = buffer.mData else { return [] }
        let channels = max(1, Int(buffer.mNumberChannels))

        if streamFormat.mFormatID == kAudioFormatLinearPCM,
           streamFormat.mBitsPerChannel == 16,
           streamFormat.mFormatFlags & kAudioFormatFlagIsSignedInteger != 0 {
            let values = UnsafeRawPointer(data).assumingMemoryBound(to: Int16.self)
            let valueCount = Int(buffer.mDataByteSize) / MemoryLayout<Int16>.size
            return interleavedMono(valueCount: valueCount, channels: channels) { index in
                Float(values[index]) / Float(Int16.max)
            }
        }

        if streamFormat.mFormatID == kAudioFormatLinearPCM,
           streamFormat.mBitsPerChannel == 32,
           streamFormat.mFormatFlags & kAudioFormatFlagIsSignedInteger != 0 {
            let values = UnsafeRawPointer(data).assumingMemoryBound(to: Int32.self)
            let valueCount = Int(buffer.mDataByteSize) / MemoryLayout<Int32>.size
            return interleavedMono(valueCount: valueCount, channels: channels) { index in
                Float(values[index]) / Float(Int32.max)
            }
        }

        let values = UnsafeRawPointer(data).assumingMemoryBound(to: Float.self)
        let valueCount = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
        return interleavedMono(valueCount: valueCount, channels: channels) { index in
            values[index]
        }
    }

    private func interleavedMono(valueCount: Int, channels: Int, valueAt: (Int) -> Float) -> [Float] {
        guard valueCount > 0 else { return [] }
        if channels <= 1 {
            return (0..<valueCount).map { clamp(valueAt($0), -1, 1) }
        }

        let frameCount = valueCount / channels
        return (0..<frameCount).map { frame in
            var total: Float = 0
            for channel in 0..<channels {
                total += valueAt(frame * channels + channel)
            }
            return clamp(total / Float(channels), -1, 1)
        }
    }

    private func append(_ samples: [Float]) {
        for sample in samples {
            ring[writeIndex] = clamp(sample, -1, 1)
            writeIndex = (writeIndex + 1) % Self.ringSize
            availableSamples = min(Self.ringSize, availableSamples + 1)
        }
        lastSampleHostTime = ProcessInfo.processInfo.systemUptime
    }

    private func maybeEmitFrame() {
        guard availableSamples >= Self.analysisSize else { return }
        let hostTime = ProcessInfo.processInfo.systemUptime
        guard lastSampleHostTime > 0, hostTime - lastSampleHostTime <= 1.25 else { return }
        guard hostTime - lastFrameHostTime >= frameInterval else { return }
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
            onLog("core audio tap scope emitted first frame")
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
        let maxLog = log(min(Self.maxBandFrequency, sampleRate * 0.48))
        return exp(minLog + (maxLog - minLog) * clamp(normalized, 0, 1))
    }

    private func goertzelMagnitude(_ samples: [Float], frequency: Double) -> Double {
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

    private func average<S: Sequence>(_ values: S) -> Double where S.Element == Double {
        var total = 0.0
        var count = 0.0
        for value in values {
            total += value
            count += 1
        }
        return count > 0 ? total / count : 0
    }

    private func clamp<T: Comparable>(_ value: T, _ minValue: T, _ maxValue: T) -> T {
        min(max(value, minValue), maxValue)
    }

    private static func describe(_ status: OSStatus) -> String {
        if status == noErr { return "noErr" }
        let bigEndian = UInt32(bitPattern: status).bigEndian
        let text = withUnsafeBytes(of: bigEndian) { rawBuffer -> String? in
            guard let base = rawBuffer.baseAddress else { return nil }
            let bytes = base.assumingMemoryBound(to: UInt8.self)
            guard (0..<4).allSatisfy({ bytes[$0] >= 32 && bytes[$0] <= 126 }) else { return nil }
            return String(bytes: UnsafeBufferPointer(start: bytes, count: 4), encoding: .macOSRoman)
        }
        if let text {
            return "\(status) '\(text)'"
        }
        return "\(status)"
    }
}
