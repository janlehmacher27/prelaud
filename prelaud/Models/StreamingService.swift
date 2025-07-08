//
//  StreamingService.swift
//  MusicPreview
//
//  Created by Jan on 08.07.25.
//

import SwiftUI

enum StreamingService: String, CaseIterable {
    case spotify = "Spotify"
    case appleMusic = "Apple Music"
    case amazonMusic = "Amazon Music"
    case youtubeMusic = "YouTube Music"
    
    var name: String {
        return self.rawValue
    }
    
    var primaryColor: Color {
        switch self {
        case .spotify: return Color(red: 0.11, green: 0.73, blue: 0.33)
        case .appleMusic: return Color(red: 0.98, green: 0.26, blue: 0.40)
        case .amazonMusic: return Color(red: 0.00, green: 0.67, blue: 0.93)
        case .youtubeMusic: return Color(red: 1.00, green: 0.00, blue: 0.00)
        }
    }
    
    // NEU: iconName Property hinzugefügt
    var iconName: String {
        switch self {
        case .spotify: return "music.note.list"
        case .appleMusic: return "music.note"
        case .amazonMusic: return "music.mic"
        case .youtubeMusic: return "play.rectangle"
        }
    }
}
