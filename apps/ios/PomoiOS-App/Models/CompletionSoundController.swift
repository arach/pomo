import AVFoundation

@MainActor
final class CompletionSoundController {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private lazy var buffer = makeBuffer()

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func play() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)

            if !engine.isRunning {
                try engine.start()
            }

            player.stop()
            player.scheduleBuffer(buffer, at: nil, options: .interrupts)
            player.play()
        } catch {
            // Haptics and the visual receipt still acknowledge completion.
        }
    }

    private func makeBuffer() -> AVAudioPCMBuffer {
        let duration = 1.25
        let frameCount = AVAudioFrameCount(format.sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let samples = buffer.floatChannelData?[0] else { return buffer }

        let frequencies = [523.25, 659.25, 783.99]
        let amplitudes = [0.13, 0.08, 0.05]
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / format.sampleRate
            let attack = min(time / 0.012, 1)
            let envelope = attack * exp(-3.2 * time)
            let signal = zip(frequencies, amplitudes).reduce(0.0) { partial, voice in
                partial + sin(2 * .pi * voice.0 * time) * voice.1
            }
            samples[frame] = Float(signal * envelope)
        }

        return buffer
    }
}
