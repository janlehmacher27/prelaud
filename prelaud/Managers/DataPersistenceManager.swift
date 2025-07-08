//
//  DataPersistenceManager.swift
//  MusicPreview
//
//  Handles local + cloud storage for albums
//

import Foundation
import UIKit

@MainActor
class DataPersistenceManager: ObservableObject {
    static let shared = DataPersistenceManager()
    
    @Published var savedAlbums: [Album] = []
    @Published var isLoading = false
    @Published var hasCloudSync = false
    
    private let albumsKey = "SavedAlbums"
    private let documentsDirectory: URL
    
    private init() {
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        loadAlbums()
    }
    
    // MARK: - Local Storage
    
    func saveAlbum(_ album: Album) {
        print("💾 Saving album: \(album.title)")
        
        // 1. Album zu Array hinzufügen
        if !savedAlbums.contains(where: { $0.id == album.id }) {
            savedAlbums.append(album)
        }
        
        // 2. Cover Image lokal speichern
        saveAlbumCoverImage(album)
        
        // 3. Album-Metadaten speichern
        saveAlbumsMetadata()
        
        // 4. Optional: Cloud-Sync
        if hasCloudSync {
            syncToCloud(album)
        }
        
        print("✅ Album saved successfully")
    }
    
    private func saveAlbumCoverImage(_ album: Album) {
        guard let coverImage = album.coverImage else { return }
        
        let imageURL = documentsDirectory.appendingPathComponent("cover_\(album.id.uuidString).jpg")
        
        if let imageData = coverImage.jpegData(compressionQuality: 0.8) {
            try? imageData.write(to: imageURL)
            print("🖼️ Cover image saved: \(imageURL.lastPathComponent)")
        }
    }
    
    private func saveAlbumsMetadata() {
        let albumData = savedAlbums.map { album in
            AlbumMetadata(
                id: album.id,
                title: album.title,
                artist: album.artist,
                releaseDate: album.releaseDate,
                songs: album.songs.map { song in
                    SongMetadata(
                        id: song.id,
                        title: song.title,
                        artist: song.artist,
                        duration: song.duration,
                        audioFileName: song.audioFileName,
                        isExplicit: song.isExplicit,
                        songId: song.songId
                    )
                }
            )
        }
        
        if let encoded = try? JSONEncoder().encode(albumData) {
            UserDefaults.standard.set(encoded, forKey: albumsKey)
        }
    }
    
    func loadAlbums() {
        print("📂 Loading saved albums...")
        isLoading = true
        
        guard let data = UserDefaults.standard.data(forKey: albumsKey),
              let albumData = try? JSONDecoder().decode([AlbumMetadata].self, from: data) else {
            print("📭 No saved albums found")
            isLoading = false
            return
        }
        
        savedAlbums = albumData.map { metadata in
            Album(
                title: metadata.title,
                artist: metadata.artist,
                songs: metadata.songs.map { songData in
                    Song(
                        title: songData.title,
                        artist: songData.artist,
                        duration: songData.duration,
                        coverImage: loadAlbumCoverImage(albumId: metadata.id),
                        audioFileName: songData.audioFileName,
                        isExplicit: songData.isExplicit,
                        songId: songData.songId
                    )
                },
                coverImage: loadAlbumCoverImage(albumId: metadata.id),
                releaseDate: metadata.releaseDate
            )
        }
        
        print("✅ Loaded \(savedAlbums.count) albums")
        isLoading = false
    }
    
    private func loadAlbumCoverImage(albumId: UUID) -> UIImage? {
        let imageURL = documentsDirectory.appendingPathComponent("cover_\(albumId.uuidString).jpg")
        return UIImage(contentsOfFile: imageURL.path)
    }
    
    func deleteAlbum(_ album: Album) {
        // Album aus Array entfernen
        savedAlbums.removeAll { $0.id == album.id }
        
        // Cover Image löschen
        let imageURL = documentsDirectory.appendingPathComponent("cover_\(album.id.uuidString).jpg")
        try? FileManager.default.removeItem(at: imageURL)
        
        // Metadaten aktualisieren
        saveAlbumsMetadata()
        
        // Cloud-Sync
        if hasCloudSync {
            deleteFromCloud(album)
        }
        
        print("🗑️ Album deleted: \(album.title)")
    }
    
    // MARK: - Cloud Sync (Optional)
    
    func enableCloudSync() {
        // Hier würdest du Apple Sign-In oder ähnliches implementieren
        hasCloudSync = true
        
        // Bestehende Alben zur Cloud hochladen
        for album in savedAlbums {
            syncToCloud(album)
        }
    }
    
    private func syncToCloud(_ album: Album) {
        // Implementation für iCloud, Firebase, oder eigenen Server
        print("☁️ Syncing album to cloud: \(album.title)")
        
        // Beispiel: Zu deinem Supabase hochladen
        Task {
            // Upload album metadata
            // Upload cover image
            // Bereits vorhandene Audio-Files sind schon in Supabase
        }
    }
    
    private func deleteFromCloud(_ album: Album) {
        print("☁️ Deleting album from cloud: \(album.title)")
        // Cloud-Löschung implementieren
    }
    
    // MARK: - Storage Info
    
    func getStorageInfo() -> (albumCount: Int, totalSize: String) {
        let albumCount = savedAlbums.count
        
        // Berechne Speicherplatz
        var totalSize: Int64 = 0
        
        for album in savedAlbums {
            // Cover Images
            let imageURL = documentsDirectory.appendingPathComponent("cover_\(album.id.uuidString).jpg")
            if let attributes = try? FileManager.default.attributesOfItem(atPath: imageURL.path) {
                totalSize += attributes[.size] as? Int64 ?? 0
            }
        }
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        
        return (albumCount, formatter.string(fromByteCount: totalSize))
    }
}

// MARK: - Data Models

struct AlbumMetadata: Codable {
    let id: UUID
    let title: String
    let artist: String
    let releaseDate: Date
    let songs: [SongMetadata]
}

struct SongMetadata: Codable {
    let id: UUID
    let title: String
    let artist: String
    let duration: TimeInterval
    let audioFileName: String?
    let isExplicit: Bool
    let songId: String?
}
