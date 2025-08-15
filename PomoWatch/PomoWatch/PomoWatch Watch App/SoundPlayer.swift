//
//  SoundPlayer.swift
//  PomoWatch Watch App
//
//  Handles audio playback for timer completion
//

import WatchKit
import AVFoundation

class SoundPlayer {
    static let shared = SoundPlayer()
    private var audioPlayer: AVAudioPlayer?
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    func playCompletionSound() {
        // Create a simple tone programmatically
        // Since we can't easily generate audio on watchOS, we'll use the system notification sound
        WKInterfaceDevice.current().play(.notification)
        
        // You can add a sound file to the project later:
        // 1. Add a .mp3 or .wav file to the Watch App target
        // 2. Uncomment and use this code:
        /*
        if let soundURL = Bundle.main.url(forResource: "completion", withExtension: "mp3") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.volume = 0.7
                audioPlayer?.play()
            } catch {
                print("Failed to play sound: \(error)")
                // Fallback to haptic
                WKInterfaceDevice.current().play(.notification)
            }
        }
        */
    }
}