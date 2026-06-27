import Foundation

enum PomoAmpVizAnalyzer {
    private static let fps = 30.0
    private static let webAudioScopeFreshnessSeconds = 0.75
    private static let nativeAudioScopeFreshnessSeconds = 2.5
    private static let minBandFrequencyHz = 45.0
    private static let maxBandFrequencyHz = 18_000.0
    private static var previousLogBands: [Double] = []
    private static var previousBassLogBands: [Double] = []
    private static var previousSource = ""
    private static var lastAnalysisHostTime = 0.0
    private static var lastOnsetHostTime = -Double.infinity
    private static var fluxMean = 0.0
    private static var fluxDeviation = 0.0
    private static var bassFluxMean = 0.0
    private static var onsetPulse = 0.0

    private struct SpectralMetrics {
        var rmsDb = -90.0
        var peakDb = -90.0
        var crestDb = 0.0
        var transient = 0.0
        var sub = 0.0
        var bass = 0.0
        var lowMid = 0.0
        var presence = 0.0
        var brilliance = 0.0
        var centroidHz = 0.0
        var bandwidthHz = 0.0
        var brightness = 0.0
        var rolloff85Hz = 0.0
        var tonality = 0.0
        var flux = 0.0
        var bassFlux = 0.0
        var onsetScore = 0.0
        var onsetPulse = 0.0
        var onset = false
    }

    static func frame(
        isPlaying: Bool,
        mediaTime: Double,
        duration: Double,
        playbackRate: Double,
        hostTime: Double,
        scope: AudioScopeFrame?,
        scopeError: String?
    ) -> PomoAmpVizData {
        let progress = duration > 0 ? clamp(mediaTime / duration, 0, 1) : 0

        if let error = scopeError, !error.isEmpty {
            return quietFrame(
                source: "blocked",
                sourceError: error,
                latencyMs: 0,
                isPlaying: isPlaying,
                mediaTime: mediaTime,
                duration: duration,
                progress: progress,
                playbackRate: playbackRate,
                hostTime: hostTime
            )
        }

        guard let scope else {
            return quietFrame(
                source: "none",
                sourceError: nil,
                latencyMs: 0,
                isPlaying: isPlaying,
                mediaTime: mediaTime,
                duration: duration,
                progress: progress,
                playbackRate: playbackRate,
                hostTime: hostTime
            )
        }

        let age = max(0, hostTime - scope.hostTime)
        let maxAge = scope.source == "coreAudioTap"
            ? nativeAudioScopeFreshnessSeconds
            : webAudioScopeFreshnessSeconds
        guard age <= maxAge else {
            return quietFrame(
                source: "stale",
                sourceError: "audio scope stale",
                latencyMs: age * 1000,
                isPlaying: isPlaying,
                mediaTime: mediaTime,
                duration: duration,
                progress: progress,
                playbackRate: playbackRate,
                hostTime: hostTime
            )
        }

        let bands = scope.bands.isEmpty ? Array(repeating: 0.0, count: 24) : scope.bands.map { clamp($0, 0, 1) }
        let waveform = scope.waveform.isEmpty ? Array(repeating: 0.0, count: 32) : scope.waveform.map { clamp($0, -1, 1) }
        let rms = clamp(scope.rms, 0, 1)
        let peak = clamp(scope.peak, 0, 1)
        let metrics = spectralMetrics(bands: bands, rms: rms, peak: peak, source: scope.source, hostTime: hostTime)
        let drop = max(clamp(max(0, peak - rms) * 1.4, 0, 1), metrics.onsetPulse * 0.86, metrics.bassFlux * 0.66)

        return PomoAmpVizData(
            version: 1,
            frame: Int(floor(hostTime * fps)),
            source: scope.source,
            sourceError: nil,
            latencyMs: age * 1000,
            hostTime: hostTime,
            mediaTime: mediaTime,
            duration: max(0, duration),
            progress: progress,
            playbackRate: playbackRate,
            isPlaying: isPlaying,
            bpm: 0,
            beatIndex: 0,
            beatPhase: 1,
            barIndex: 0,
            barPhase: 1,
            drop: drop,
            rms: rms,
            rmsDb: metrics.rmsDb,
            peak: peak,
            peakDb: metrics.peakDb,
            crestDb: metrics.crestDb,
            transient: metrics.transient,
            low: clamp(scope.low, 0, 1),
            mid: clamp(scope.mid, 0, 1),
            high: clamp(scope.high, 0, 1),
            sub: metrics.sub,
            bass: metrics.bass,
            lowMid: metrics.lowMid,
            presence: metrics.presence,
            brilliance: metrics.brilliance,
            centroidHz: metrics.centroidHz,
            bandwidthHz: metrics.bandwidthHz,
            brightness: metrics.brightness,
            rolloff85Hz: metrics.rolloff85Hz,
            tonality: metrics.tonality,
            flux: metrics.flux,
            bassFlux: metrics.bassFlux,
            onsetScore: metrics.onsetScore,
            onsetPulse: metrics.onsetPulse,
            onset: metrics.onset,
            bands: bands,
            waveform: waveform
        )
    }

    private static func quietFrame(
        source: String,
        sourceError: String?,
        latencyMs: Double,
        isPlaying: Bool,
        mediaTime: Double,
        duration: Double,
        progress: Double,
        playbackRate: Double,
        hostTime: Double
    ) -> PomoAmpVizData {
        resetSpectralState()
        return PomoAmpVizData(
            version: 1,
            frame: Int(floor(hostTime * fps)),
            source: source,
            sourceError: sourceError,
            latencyMs: latencyMs,
            hostTime: hostTime,
            mediaTime: mediaTime,
            duration: max(0, duration),
            progress: progress,
            playbackRate: playbackRate,
            isPlaying: isPlaying,
            bpm: 0,
            beatIndex: 0,
            beatPhase: 1,
            barIndex: 0,
            barPhase: 1,
            drop: 0,
            rms: 0,
            rmsDb: -90,
            peak: 0,
            peakDb: -90,
            crestDb: 0,
            transient: 0,
            low: 0,
            mid: 0,
            high: 0,
            sub: 0,
            bass: 0,
            lowMid: 0,
            presence: 0,
            brilliance: 0,
            centroidHz: 0,
            bandwidthHz: 0,
            brightness: 0,
            rolloff85Hz: 0,
            tonality: 0,
            flux: 0,
            bassFlux: 0,
            onsetScore: 0,
            onsetPulse: 0,
            onset: false,
            bands: Array(repeating: 0.0, count: 24),
            waveform: Array(repeating: 0.0, count: 32)
        )
    }

    private static func spectralMetrics(bands: [Double], rms: Double, peak: Double, source: String, hostTime: Double) -> SpectralMetrics {
        var metrics = SpectralMetrics()
        metrics.rmsDb = decibels(rms)
        metrics.peakDb = decibels(peak)
        metrics.crestDb = max(0, metrics.peakDb - metrics.rmsDb)
        metrics.transient = clamp((metrics.crestDb - 6) / 12, 0, 1)
        metrics.sub = averageRange(bands, 0..<2)
        metrics.bass = averageRange(bands, 2..<6)
        metrics.lowMid = averageRange(bands, 6..<9)
        metrics.presence = averageRange(bands, 15..<20)
        metrics.brilliance = averageRange(bands, 20..<bands.count)

        let centers = bandCenters(count: bands.count)
        let magnitudes = bands.map { max(0, $0) }
        let powers = magnitudes.map { max(0, $0 * $0) }
        let magnitudeTotal = magnitudes.reduce(0, +)
        let powerTotal = powers.reduce(0, +)

        if magnitudeTotal > 0.000001 {
            metrics.centroidHz = zip(centers, magnitudes).reduce(0) { $0 + $1.0 * $1.1 } / magnitudeTotal
            let spread = zip(centers, magnitudes).reduce(0) { total, item in
                let delta = item.0 - metrics.centroidHz
                return total + item.1 * delta * delta
            } / magnitudeTotal
            metrics.bandwidthHz = sqrt(max(0, spread))
            metrics.brightness = logNormalize(metrics.centroidHz, min: 80, max: 12_000)
        }

        if powerTotal > 0.000001 {
            var cumulative = 0.0
            for (index, power) in powers.enumerated() {
                cumulative += power
                if cumulative >= powerTotal * 0.85 {
                    metrics.rolloff85Hz = centers[min(index, centers.count - 1)]
                    break
                }
            }

            let epsilon = 0.000001
            let arithmetic = powers.reduce(0) { $0 + $1 + epsilon } / Double(max(1, powers.count))
            let geometric = exp(powers.reduce(0) { $0 + log($1 + epsilon) } / Double(max(1, powers.count)))
            metrics.tonality = clamp(1 - geometric / max(arithmetic, epsilon), 0, 1)
        }

        let logBands = bands.map { log1p($0 * 12.0) }
        let bassLogBands = Array(logBands.prefix(6))
        let reset = previousSource != source || previousLogBands.count != logBands.count
        let dt = lastAnalysisHostTime > 0 ? clamp(hostTime - lastAnalysisHostTime, 1.0 / 120.0, 0.25) : 1.0 / fps

        if reset {
            previousLogBands = logBands
            previousBassLogBands = bassLogBands
            previousSource = source
            lastAnalysisHostTime = hostTime
            onsetPulse = 0
            return metrics
        }

        metrics.flux = positiveFlux(current: logBands, previous: previousLogBands)
        metrics.bassFlux = positiveFlux(current: bassLogBands, previous: previousBassLogBands)
        previousLogBands = logBands
        previousBassLogBands = bassLogBands
        previousSource = source
        lastAnalysisHostTime = hostTime

        let meanAlpha = 1 - exp(-dt / 1.0)
        fluxMean += (metrics.flux - fluxMean) * meanAlpha
        fluxDeviation += (abs(metrics.flux - fluxMean) - fluxDeviation) * meanAlpha
        bassFluxMean += (metrics.bassFlux - bassFluxMean) * meanAlpha

        let threshold = fluxMean + fluxDeviation * 1.35 + 0.018
        metrics.onsetScore = clamp(max(0, (metrics.flux - threshold) / max(0.018, fluxDeviation + 0.006)), 0, 3)
        let bassKick = metrics.bassFlux > max(0.035, bassFluxMean * 1.55)
        metrics.onset = metrics.onsetScore > 1.0 && bassKick && hostTime - lastOnsetHostTime > 0.09
        if metrics.onset {
            onsetPulse = 1
            lastOnsetHostTime = hostTime
        } else {
            onsetPulse *= exp(-dt / 0.12)
        }
        metrics.onsetPulse = clamp(onsetPulse, 0, 1)
        return metrics
    }

    private static func resetSpectralState() {
        previousLogBands = []
        previousBassLogBands = []
        previousSource = ""
        lastAnalysisHostTime = 0
        lastOnsetHostTime = -Double.infinity
        fluxMean = 0
        fluxDeviation = 0
        bassFluxMean = 0
        onsetPulse = 0
    }

    private static func positiveFlux(current: [Double], previous: [Double]) -> Double {
        guard !current.isEmpty, current.count == previous.count else { return 0 }
        let total = zip(current, previous).reduce(0) { $0 + max(0, $1.0 - $1.1) }
        return total / Double(current.count)
    }

    private static func bandCenters(count: Int) -> [Double] {
        guard count > 0 else { return [] }
        let minLog = log(minBandFrequencyHz)
        let maxLog = log(maxBandFrequencyHz)
        return (0..<count).map { index in
            let normalized = Double(index) / Double(max(1, count - 1))
            return exp(minLog + (maxLog - minLog) * normalized)
        }
    }

    private static func averageRange(_ values: [Double], _ range: Range<Int>) -> Double {
        guard !values.isEmpty else { return 0 }
        let lower = max(0, min(values.count, range.lowerBound))
        let upper = max(lower, min(values.count, range.upperBound))
        guard lower < upper else { return 0 }
        return average(values[lower..<upper])
    }

    private static func average<S: Sequence>(_ values: S) -> Double where S.Element == Double {
        var total = 0.0
        var count = 0.0
        for value in values {
            total += value
            count += 1
        }
        return count > 0 ? total / count : 0
    }

    private static func decibels(_ value: Double) -> Double {
        max(-90, 20 * log10(max(0.000001, value)))
    }

    private static func logNormalize(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        let minLog = log(minValue)
        let maxLog = log(maxValue)
        return clamp((log(Swift.max(value, 0.000001)) - minLog) / (maxLog - minLog), 0, 1)
    }

    private static func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
        min(max(value, minValue), maxValue)
    }
}
