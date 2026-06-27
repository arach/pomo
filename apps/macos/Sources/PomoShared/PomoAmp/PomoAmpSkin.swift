import Foundation

struct PomoAmpSkinManifest: Codable, Identifiable, Equatable {
    struct Size: Codable, Equatable {
        var width: Double
        var height: Double
    }

    var id: String
    var name: String
    var version: String
    var engine: String
    var entry: String
    var size: Size?
    var author: String?

    var supportsHTML: Bool {
        engine == "html@1"
    }
}

struct PomoAmpSkin: Identifiable, Equatable {
    var id: String { manifest.id }
    let manifest: PomoAmpSkinManifest
    let directory: URL

    var entryURL: URL {
        directory.appendingPathComponent(manifest.entry)
    }
}

struct PomoAmpSkinState: Codable, Equatable {
    struct Shortcut: Codable, Equatable {
        var key: String
        var label: String
    }

    var isPlaying: Bool
    var title: String
    var url: String
    var thumbnailURL: String
    var source: String
    var videoOpen: Bool
    var videoExpanded: Bool
    var isBig: Bool
    var face: String
    var shortcuts: [Shortcut]
}

struct PomoAmpVizData: Codable, Equatable {
    var version: Int
    var frame: Int
    var source: String
    var sourceError: String?
    var latencyMs: Double
    var hostTime: Double
    var mediaTime: Double
    var duration: Double
    var progress: Double
    var playbackRate: Double
    var isPlaying: Bool
    var bpm: Double
    var beatIndex: Int
    var beatPhase: Double
    var barIndex: Int
    var barPhase: Double
    var drop: Double
    var rms: Double
    var rmsDb: Double
    var peak: Double
    var peakDb: Double
    var crestDb: Double
    var transient: Double
    var low: Double
    var mid: Double
    var high: Double
    var sub: Double
    var bass: Double
    var lowMid: Double
    var presence: Double
    var brilliance: Double
    var centroidHz: Double
    var bandwidthHz: Double
    var brightness: Double
    var rolloff85Hz: Double
    var tonality: Double
    var flux: Double
    var bassFlux: Double
    var onsetScore: Double
    var onsetPulse: Double
    var onset: Bool
    var bands: [Double]
    var waveform: [Double]
}

enum PomoAmpSkinAction: String {
    case playPause
    case previousTrack
    case nextTrack
    case previousSection
    case nextSection
    case toggleVideo
    case showVideo
    case hideVideo
    case expandVideo
    case minimizeVideo
    case showVideoPage
    case showVideoPlayer
    case pasteURL
    case enableAudioScope
    case showShortcuts
    case minimizeWindow
    case toggleBig
    case enterBig
    case exitBig
    case hide
    case nextNativeFace
}

extension PomoAmpSkinAction {
    init?(skinName name: String) {
        if let exact = Self(rawValue: name) {
            self = exact
            return
        }

        let normalized = name
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }

        switch normalized {
        case "playpause", "toggleplay", "togglepause", "play", "pause", "space":
            self = .playPause
        case "previoustrack", "prevtrack", "previous", "prev":
            self = .previousTrack
        case "nexttrack", "next":
            self = .nextTrack
        case "previoussection", "prevsection", "previoustimestampsection", "prevtimestampsection", "previouschapter", "prevchapter", "left":
            self = .previousSection
        case "nextsection", "nexttimestampsection", "nextchapter", "right":
            self = .nextSection
        case "togglevideo", "video", "vid":
            self = .toggleVideo
        case "showvideo", "showvid", "openvideo", "openvid":
            self = .showVideo
        case "hidevideo", "hidevid", "closevideo", "closevid":
            self = .hideVideo
        case "expandvideo", "expand", "fullpage":
            self = .expandVideo
        case "minimizevideo", "collapsevideo", "collapse":
            self = .minimizeVideo
        case "showvideopage", "showpage", "page":
            self = .showVideoPage
        case "showvideoplayer", "showplayer", "player", "plyr":
            self = .showVideoPlayer
        case "pasteurl", "pasteyoutubeurl", "paste", "url":
            self = .pasteURL
        case "enableaudioscope", "enablevisualizer", "audioscope", "scope", "enableviz", "viz":
            self = .enableAudioScope
        case "showshortcuts", "shortcuts", "help":
            self = .showShortcuts
        case "minimizewindow", "minimize", "hidewindow":
            self = .minimizeWindow
        case "togglebig", "big", "togglecompact":
            self = .toggleBig
        case "enterbig", "gobig":
            self = .enterBig
        case "exitbig", "compact", "small":
            self = .exitBig
        case "hide", "close":
            self = .hide
        case "nextnativeface", "nextface", "face":
            self = .nextNativeFace
        default:
            return nil
        }
    }
}
