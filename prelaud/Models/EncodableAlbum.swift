//
//  EncodableAlbum.swift
//  prelaud
//
//  Codable version of Album for UserDefaults storage
//

import Foundation

struct EncodableAlbum: Codable, Identifiable {
    let id: UUID
    let title: String
    let artist: String
    let songs: [EncodableSong]
    let releaseDate: Date
    let shareId: String
    let ownerId: String
    let ownerUsername: String
    let sharedAt: Date?
    
    init(from album: Album, shareId: String, ownerId: String, ownerUsername: String) {
        self.id = album.id
        self.title = album.title
        self.artist = album.artist
        self.songs = album.songs.map { song in
            EncodableSong(
                title: song.title,
                artist: song.artist,
                duration: song.duration
            )
        }
        self.releaseDate = album.releaseDate
        self.shareId = shareId
        self.ownerId = ownerId
        self.ownerUsername = ownerUsername
        self.sharedAt = album.sharedAt
    }
    
    // MARK: - Missing toAlbum() method
    func toAlbum() -> Album {
        var album = Album(
            title: title,
            artist: artist,
            songs: songs.map { encodableSong in
                Song(
                    title: encodableSong.title,
                    artist: encodableSong.artist,
                    duration: encodableSong.duration
                )
            },
            coverImage: nil, // Cover images are handled separately
            releaseDate: releaseDate
        )
        
        // Set sharing properties
        album.shareId = shareId.isEmpty ? nil : shareId
        album.ownerId = ownerId.isEmpty ? nil : ownerId
        album.ownerUsername = ownerUsername.isEmpty ? nil : ownerUsername
        album.sharedAt = sharedAt
        
        return album
    }
}

struct EncodableSong: Codable {
    let title: String
    let artist: String
    let duration: TimeInterval
}
