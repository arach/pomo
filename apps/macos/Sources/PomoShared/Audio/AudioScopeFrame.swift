import Foundation

struct AudioScopeFrame: Equatable {
    var source: String
    var hostTime: Double
    var mediaTime: Double
    var duration: Double
    var playbackRate: Double
    var bands: [Double]
    var waveform: [Double]
    var rms: Double
    var peak: Double
    var low: Double
    var mid: Double
    var high: Double
}
