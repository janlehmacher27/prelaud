//
//  EncodableAlbum.swift - FIXED
//  prelaud
//
//  Codable Wrapper für Album-Persistierung
//

import Foundation
import UIKit

// MARK: - Encodable Album
struct EncodableAlbum: Codable {
    let id: UUID
    let title: String
    let artist: String
    let songs: [EncodableSong]
    let releaseDate: Date
    let shareId: String
    let ownerId: String?
    let ownerUsername: String?
    
    // FIXED: Async initializer für MainActor-Zugriff
    @MainActor
    init(from album: Album, shareId: String) {
        self.id = album.id
        self.title = album.title
        self.artist = album.artist
        self.songs = album.songs.map { EncodableSong(from: $0) }
        self.releaseDate = album.releaseDate
        self.shareId = shareId
        self.ownerId = UserProfileManager.shared.userProfile?.id.uuidString
        self.ownerUsername = UserProfileManager.shared.userProfile?.username
    }
    
    // FIXED: Statischer initializer ohne UserProfileManager-Zugriff
    init(from album: Album, shareId: String, ownerId: String?, ownerUsername: String?) {
        self.id = album.id
        self.title = album.title
        self.artist = album.artist
        self.songs = album.songs.map { EncodableSong(from: $0) }
        self.releaseDate = album.releaseDate
        self.shareId = shareId
        self.ownerId = ownerId
        self.ownerUsername = ownerUsername
    }
    
    func toAlbum() -> Album {
            // Erstelle Album mit neuer ID (kann nicht vermieden werden wegen struct-Design)
            var album = Album(
                title: title,
                artist: artist,
                songs: songs.map { $0.toSong() },
                coverImage: nil, // Cover Images werden separat behandelt
                releaseDate: releaseDate
            )
            
            // Setze sharing properties
            album.ownerId = ownerId
            album.ownerUsername = ownerUsername
            album.shareId = shareId
            
            print("🔍 DEBUG - Created album from EncodableAlbum:")
            print("  - Original ID: \(self.id)")
            print("  - New ID: \(album.id)")
            print("  - Title: \(album.title)")
            print("  - Artist: \(album.artist)")
            print("  - Songs: \(album.songs.count)")
            print("  - ShareID: \(album.shareId ?? "none")")
            print("  - Owner: \(album.ownerUsername ?? "none")")
            
            // Debug each song
            for (index, song) in album.songs.enumerated() {
                print("  - Song \(index): \(song.title) | AudioFile: \(song.audioFileName ?? "none") | SongID: \(song.songId ?? "none")")
            }
            
            return album
        }
}

// MARK: - Encodable Song
struct EncodableSong: Codable {
    let id: UUID
    let title: String
    let artist: String
    let duration: TimeInterval
    let audioFileName: String?
    let isExplicit: Bool
    let songId: String?
    
    init(from song: Song) {
        self.id = song.id
        self.title = song.title
        self.artist = song.artist
        self.duration = song.duration
        self.audioFileName = song.audioFileName
        self.isExplicit = song.isExplicit
        self.songId = song.songId
    }
    
    func toSong() -> Song {
            let song = Song(
                title: title,
                artist: artist,
                duration: duration,
                coverImage: nil,
                audioFileName: audioFileName,
                isExplicit: isExplicit,
                songId: songId
            )
            
            return song
        }
}
