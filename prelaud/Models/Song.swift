//
//  Song.swift (ERWEITERT)
//  MusicPreview
//
//  Created by Jan on 08.07.25.
//

import Foundation
import UIKit

struct Song {
    let id = UUID()
    var title: String
    var artist: String
    var duration: TimeInterval
    var coverImage: UIImage?
    var audioFileName: String?
    var isExplicit: Bool = false
    var songId: String? // NEU: Eindeutige Song-ID für Dropbox-Lookup
    
    // Initializer mit allen Parametern
    init(title: String, artist: String, duration: TimeInterval, coverImage: UIImage? = nil, audioFileName: String? = nil, isExplicit: Bool = false, songId: String? = nil) {
        self.title = title
        self.artist = artist
        self.duration = duration
        self.coverImage = coverImage
        self.audioFileName = audioFileName
        self.isExplicit = isExplicit
        self.songId = songId
    }
}
