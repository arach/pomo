import Foundation

/// A saved audio source — a curated station/track the user can recall instantly.
/// `url` is the page URL (resolved fresh on play, since stream URLs expire).
struct Favorite: Codable, Identifiable, Equatable {
    var title: String
    var url: String

    var id: String { url }
}
