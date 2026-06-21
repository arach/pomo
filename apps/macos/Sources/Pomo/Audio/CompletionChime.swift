import AVFoundation
import AppKit

/// Synthesizes a gentle completion chime at runtime (no audio assets): a C-major
/// triad with an exponential decay, rendered into a PCM buffer and played
/// through AVAudioEngine.
@MainActor
final class CompletionChime {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var wired = false

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
            ?? AVAudioFormat()
    }

    private func wireIfNeeded() {
        guard !wired else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        wired = true
    }

    func play(volume: Double) {
        let clamped = Float(min(1.0, max(0.0, volume)))
        guard clamped > 0, let buffer = makeBuffer(volume: clamped) else {
            NSSound.beep()
            return
        }
        wireIfNeeded()
        do {
            if !engine.isRunning { try engine.start() }
            player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            player.play()
        } catch {
            NSSound.beep()
        }
    }

    private func makeBuffer(volume: Float) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let duration = 1.7
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = frameCount

        // C5 / E5 / G5 triad, upper partials quieter.
        let partials: [(freq: Double, amp: Double)] = [
            (523.25, 0.50),
            (659.25, 0.30),
            (783.99, 0.20),
        ]
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope = exp(-3.0 * t)
            var sample = 0.0
            for partial in partials {
                sample += partial.amp * sin(2.0 * Double.pi * partial.freq * t)
            }
            channel[i] = Float(sample * envelope) * volume * 0.6
        }
        return buffer
    }
}
