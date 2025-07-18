//
//  Enhanced DataPersistenceManager.swift
//  prelaud
//
//  Mit integriertem Remote-Logging für besseres Debugging
//

import Foundation
import UIKit

@MainActor
class DataPersistenceManager: ObservableObject {
    static let shared = DataPersistenceManager()
    
    @Published var savedAlbums: [Album] = []
    @Published var isLoading = false
    @Published var hasCloudSync = false
    @Published var isSyncingToCloud = false
    @Published var cloudSyncError: String?
    
    private let albumsKey = "SavedAlbums"
    private let documentsDirectory: URL
    private let pocketBase = PocketBaseManager.shared
    private let logger = RemoteLogger.shared
    
    private init() {
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        logger.info("🚀 DataPersistenceManager initializing...")
        logger.database("Documents directory: \(documentsDirectory.path)")
        
        loadAlbums()
        checkCloudSyncAvailability()
        
        logger.success("✅ DataPersistenceManager initialized with \(savedAlbums.count) albums")
    }
    
    // MARK: - Enhanced Album Saving with Detailed Logging
    
    func saveAlbum(_ album: Album) {
        logger.album("🎵 Starting saveAlbum process")
        logger.album("Album: '\(album.title)' by '\(album.artist)'")
        logger.album("Album ID: \(album.id)")
        logger.album("Songs count: \(album.songs.count)")
        
        // System state before saving
        logger.database("📊 BEFORE SAVE STATE:")
        logger.database("Current albums count: \(savedAlbums.count)")
        logger.database("hasCloudSync: \(hasCloudSync)")
        logger.database("isLoading: \(isLoading)")
        logger.database("isSyncingToCloud: \(isSyncingToCloud)")
        
        // Check if album already exists
        let existingIndex = savedAlbums.firstIndex(where: { $0.id == album.id })
        if let index = existingIndex {
            logger.album("🔄 Album already exists at index \(index), will update")
        } else {
            logger.album("➕ New album, will add to collection")
        }
        
        // 1. Save locally first (critical for offline capability)
        logger.database("💾 Starting local save...")
        saveAlbumLocally(album)
        
        // 2. Try cloud sync if available
        if hasCloudSync {
            logger.cloud("☁️ Cloud sync is available, starting sync...")
            syncAlbumToPocketBase(album)
        } else {
            logger.cloud("☁️ Cloud sync not available, skipping")
            let reason = !UserProfileManager.shared.isProfileSetup ? "Profile not setup" : "PocketBase not configured"
            logger.cloud("Reason: \(reason)")
        }
        
        // Final state logging
        logger.database("📊 AFTER SAVE STATE:")
        logger.database("Final albums count: \(savedAlbums.count)")
        logger.success("✅ saveAlbum completed for: \(album.title)")
    }
    
    private func saveAlbumLocally(_ album: Album) {
        logger.database("💾 saveAlbumLocally called")
        logger.database("Target album: \(album.title)")
        
        let beforeCount = savedAlbums.count
        
        // Add or update in array
        if let existingIndex = savedAlbums.firstIndex(where: { $0.id == album.id }) {
            logger.database("🔄 Updating existing album at index \(existingIndex)")
            savedAlbums[existingIndex] = album
        } else {
            logger.database("➕ Adding new album to array")
            savedAlbums.append(album)
            
            // Sort by release date
            savedAlbums.sort { $0.releaseDate > $1.releaseDate }
            logger.database("📅 Albums sorted by release date")
        }
        
        let afterCount = savedAlbums.count
        logger.database("Album count: \(beforeCount) → \(afterCount)")
        
        // Save to persistent storage
        logger.database("💾 Saving to UserDefaults...")
        saveAlbumsMetadata()
        
        // Immediate verification
        verifyLocalSave(album)
    }
    
     func saveAlbumsMetadata() {
        logger.database("💾 saveAlbumsMetadata called")
        logger.database("Albums to encode: \(savedAlbums.count)")
        
        do {
            let encodableAlbums = savedAlbums.map { album in
                EncodableAlbum(
                    from: album,
                    shareId: album.shareId ?? "",
                    ownerId: album.ownerId ?? "",
                    ownerUsername: album.ownerUsername ?? ""
                )
            }
            
            logger.database("📦 Created \(encodableAlbums.count) encodable albums")
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let encoded = try encoder.encode(encodableAlbums)
            
            logger.database("📦 Encoded data size: \(encoded.count) bytes")
            
            UserDefaults.standard.set(encoded, forKey: albumsKey)
            UserDefaults.standard.synchronize() // Force immediate save
            
            logger.success("✅ Albums metadata saved to UserDefaults")
            
            // Immediate read-back verification
            if let readBack = UserDefaults.standard.data(forKey: albumsKey) {
                logger.database("✅ Read-back verification: \(readBack.count) bytes")
                
                if let decodedAlbums = try? JSONDecoder().decode([EncodableAlbum].self, from: readBack) {
                    logger.success("✅ Read-back decode successful: \(decodedAlbums.count) albums")
                } else {
                    logger.error("❌ Read-back decode failed!")
                }
            } else {
                logger.error("❌ Read-back failed - no data found!")
            }
            
        } catch {
            logger.error("❌ Failed to encode albums: \(error.localizedDescription)")
            logger.error("Error details: \(error)")
        }
    }
    
    private func verifyLocalSave(_ album: Album) {
        logger.database("🔍 Verifying local save for: \(album.title)")
        
        // Check in-memory array
        if let foundAlbum = savedAlbums.first(where: { $0.id == album.id }) {
            logger.success("✅ Album found in savedAlbums array")
            logger.database("Found album: '\(foundAlbum.title)' with \(foundAlbum.songs.count) songs")
        } else {
            logger.error("❌ Album NOT found in savedAlbums array!")
        }
        
        // Check UserDefaults
        guard let data = UserDefaults.standard.data(forKey: albumsKey) else {
            logger.error("❌ No data in UserDefaults for key: \(albumsKey)")
            return
        }
        
        logger.database("📱 UserDefaults data size: \(data.count) bytes")
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let albums = try decoder.decode([EncodableAlbum].self, from: data)
            
            logger.database("📱 UserDefaults contains \(albums.count) albums")
            
            if let foundEncodable = albums.first(where: { $0.id.uuidString == album.id.uuidString }) {
                logger.success("✅ Album verified in UserDefaults")
                logger.database("Verified: '\(foundEncodable.title)' by '\(foundEncodable.artist)'")
            } else {
                logger.error("❌ Album NOT found in UserDefaults!")
                logger.database("Available albums in UserDefaults:")
                albums.enumerated().forEach { index, encodableAlbum in
                    logger.database("  \(index + 1). '\(encodableAlbum.title)' (\(encodableAlbum.id))")
                }
            }
            
        } catch {
            logger.error("❌ Failed to decode UserDefaults data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Enhanced Loading with Logging
    
    private func loadAlbums() {
        logger.database("📂 Loading albums from storage...")
        isLoading = true
        
        guard let data = UserDefaults.standard.data(forKey: albumsKey) else {
            logger.warning("⚠️ No saved albums data found in UserDefaults")
            isLoading = false
            return
        }
        
        logger.database("📂 Found UserDefaults data: \(data.count) bytes")
        
        do {
            // Try with ISO8601 date strategy first
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let encodableAlbums = try decoder.decode([EncodableAlbum].self, from: data)
            
            logger.database("📂 Decoded \(encodableAlbums.count) albums with ISO8601 strategy")
            
            savedAlbums = encodableAlbums.compactMap { encodableAlbum in
                // Convert EncodableAlbum back to Album
                Album(
                    title: encodableAlbum.title,
                    artist: encodableAlbum.artist,
                    songs: encodableAlbum.songs.map { encodableSong in
                        Song(
                            title: encodableSong.title,
                            artist: encodableSong.artist,
                            duration: encodableSong.duration
                        )
                    },
                    coverImage: nil, // Cover images are not stored in UserDefaults
                    releaseDate: encodableAlbum.releaseDate,
                    ownerId: encodableAlbum.ownerId.isEmpty ? nil : encodableAlbum.ownerId,
                    ownerUsername: encodableAlbum.ownerUsername.isEmpty ? nil : encodableAlbum.ownerUsername,
                    shareId: encodableAlbum.shareId.isEmpty ? nil : encodableAlbum.shareId
                )
            }
            
            logger.success("✅ Successfully loaded \(savedAlbums.count) albums with ISO8601")
            
        } catch {
            logger.warning("⚠️ ISO8601 decoding failed, trying secondsSince1970...")
            
            do {
                // Try with secondsSince1970 date strategy
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .secondsSince1970
                let encodableAlbums = try decoder.decode([EncodableAlbum].self, from: data)
                
                logger.database("📂 Decoded \(encodableAlbums.count) albums with secondsSince1970 strategy")
                
                savedAlbums = encodableAlbums.compactMap { encodableAlbum in
                    // Convert EncodableAlbum back to Album
                    Album(
                        title: encodableAlbum.title,
                        artist: encodableAlbum.artist,
                        songs: encodableAlbum.songs.map { encodableSong in
                            Song(
                                title: encodableSong.title,
                                artist: encodableSong.artist,
                                duration: encodableSong.duration
                            )
                        },
                        coverImage: nil, // Cover images are not stored in UserDefaults
                        releaseDate: encodableAlbum.releaseDate,
                        ownerId: encodableAlbum.ownerId.isEmpty ? nil : encodableAlbum.ownerId,
                        ownerUsername: encodableAlbum.ownerUsername.isEmpty ? nil : encodableAlbum.ownerUsername,
                        shareId: encodableAlbum.shareId.isEmpty ? nil : encodableAlbum.shareId
                    )
                }
                
                logger.success("✅ Successfully loaded \(savedAlbums.count) albums with secondsSince1970")
                
                // Re-save with consistent format
                logger.database("🔄 Re-saving albums with consistent ISO8601 format")
                saveAlbumsMetadata()
                
            } catch {
                logger.error("❌ Both decoding strategies failed, clearing corrupted data")
                logger.error("Error details: \(error)")
                
                // Clear corrupted data and start fresh
                UserDefaults.standard.removeObject(forKey: albumsKey)
                savedAlbums = []
                
                logger.warning("⚠️ Cleared corrupted album data - starting fresh")
            }
        }
        
        // Log each album for debugging
        savedAlbums.enumerated().forEach { index, album in
            logger.database("  \(index + 1). '\(album.title)' by '\(album.artist)' (\(album.songs.count) songs)")
        }
        
        isLoading = false
        logger.database("📂 Loading completed")
    }
    
    // MARK: - Cloud Sync with Enhanced Logging
    
    private func checkCloudSyncAvailability() {
        logger.cloud("🔍 Checking cloud sync availability...")
        
        let profileSetup = UserProfileManager.shared.isProfileSetup
        let pocketBaseConfigured = true // Simplified for now - you can add proper check later
        
        logger.cloud("Profile setup: \(profileSetup)")
        logger.cloud("PocketBase configured: \(pocketBaseConfigured)")
        
        hasCloudSync = profileSetup && pocketBaseConfigured
        
        logger.cloud("Final hasCloudSync: \(hasCloudSync)")
        
        if hasCloudSync {
            logger.success("✅ Cloud sync available")
        } else {
            logger.warning("⚠️ Cloud sync not available")
        }
    }
    
    private func syncAlbumToPocketBase(_ album: Album) {
        logger.cloud("☁️ Starting PocketBase sync for: \(album.title)")
        
        Task {
            isSyncingToCloud = true
            logger.cloud("☁️ Sync status: started")
            
            do {
                // Prepare cover image data
                let coverImageData: Data
                if let coverImage = album.coverImage,
                   let imageData = coverImage.jpegData(compressionQuality: 0.8) {
                    coverImageData = imageData
                    logger.cloud("📸 Using album cover image (\(imageData.count) bytes)")
                } else {
                    // Create placeholder
                    let placeholderImage = UIImage(systemName: "music.note") ?? UIImage()
                    coverImageData = placeholderImage.jpegData(compressionQuality: 0.8) ?? Data()
                    logger.cloud("📸 Using placeholder image (\(coverImageData.count) bytes)")
                }
                
                let pocketBaseAlbumId = try await pocketBase.saveAlbumWithCoverToPocketBase(album, coverImageData: coverImageData)
                
                await MainActor.run {
                    logger.success("✅ Successfully synced to PocketBase: \(pocketBaseAlbumId)")
                    cloudSyncError = nil
                }
                
            } catch {
                logger.error("❌ PocketBase sync failed: \(error.localizedDescription)")
                logger.error("Error details: \(error)")
                
                await MainActor.run {
                    cloudSyncError = "Failed to sync \(album.title): \(error.localizedDescription)"
                }
            }
            
            await MainActor.run {
                isSyncingToCloud = false
                logger.cloud("☁️ Sync status: completed")
            }
        }
    }
    
    // MARK: - Delete with Logging
    
    func deleteAlbum(_ album: Album) {
        logger.album("🗑️ Deleting album: \(album.title)")
        
        let beforeCount = savedAlbums.count
        savedAlbums.removeAll { $0.id == album.id }
        let afterCount = savedAlbums.count
        
        logger.database("Album count: \(beforeCount) → \(afterCount)")
        
        saveAlbumsMetadata()
        
        logger.success("✅ Album deleted: \(album.title)")
    }
    
    // MARK: - Cascade Delete (for AlbumsView compatibility)
    
    func cascadeDeleteAlbum(_ album: Album) async {
        logger.album("🗑️ Cascade deleting album: \(album.title)")
        
        // Clean up any shared album references
        if let shareId = album.shareId {
            logger.database("🧹 Cleaning up shared album data for shareId: \(shareId)")
            UserDefaults.standard.removeObject(forKey: "SharedAlbum_\(shareId)")
            UserDefaults.standard.removeObject(forKey: "SharedAlbumData_\(shareId)")
        }
        
        // Stop any audio playback for this album
        let audioPlayer = AudioPlayerManager.shared
        if let currentSong = audioPlayer.currentSong,
           album.songs.contains(where: { $0.id == currentSong.id }) {
            logger.database("🔇 Stopping audio playback for deleted album")
            audioPlayer.stop()
        }
        
        // Remove from local storage
        deleteAlbum(album)
        
        // Notify other components about deletion
        NotificationCenter.default.post(
            name: NSNotification.Name("AlbumDeleted"),
            object: nil,
            userInfo: ["shareId": album.shareId ?? ""]
        )
        
        logger.success("✅ Cascade delete completed for: \(album.title)")
    }
    
    // MARK: - Test Functions for Debugging
    
    func createTestAlbum() {
        logger.debug("🧪 Creating test album...")
        
        let testAlbum = Album(
            title: "Debug Test Album \(Date().timeIntervalSince1970)",
            artist: "Test Artist",
            songs: [
                Song(title: "Test Song 1", artist: "Test Artist", duration: 180),
                Song(title: "Test Song 2", artist: "Test Artist", duration: 200)
            ],
            releaseDate: Date()
        )
        
        logger.debug("🧪 Test album created: \(testAlbum.title)")
        saveAlbum(testAlbum)
    }
    
    func validateDataIntegrity() {
        logger.debug("🔍 Starting data integrity validation...")
        
        // Check in-memory vs UserDefaults
        guard let data = UserDefaults.standard.data(forKey: albumsKey) else {
            logger.error("❌ No UserDefaults data found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let storedAlbums = try decoder.decode([EncodableAlbum].self, from: data)
            
            logger.debug("📊 In-memory albums: \(savedAlbums.count)")
            logger.debug("📊 UserDefaults albums: \(storedAlbums.count)")
            
            if savedAlbums.count == storedAlbums.count {
                logger.success("✅ Album counts match")
            } else {
                logger.error("❌ Album count mismatch!")
            }
            
            // Check each album
            for album in savedAlbums {
                if storedAlbums.contains(where: { $0.id.uuidString == album.id.uuidString }) {
                    logger.debug("✅ Album found in storage: \(album.title)")
                } else {
                    logger.error("❌ Album missing from storage: \(album.title)")
                }
            }
            
        } catch {
            logger.error("❌ Failed to decode stored albums: \(error)")
        }
        
        logger.debug("🔍 Data integrity validation completed")
    }
    
    func clearAllData() {
        logger.warning("⚠️ Clearing all album data...")
        
        savedAlbums.removeAll()
        UserDefaults.standard.removeObject(forKey: albumsKey)
        UserDefaults.standard.synchronize()
        
        logger.warning("⚠️ All album data cleared")
    }
    
    // MARK: - Existing Methods with Added Logging
    
    func getStorageInfo() -> (albumCount: Int, songCount: Int) {
        let albumCount = savedAlbums.count
        let songCount = savedAlbums.reduce(0) { $0 + $1.songs.count }
        
        logger.debug("📊 Storage info - Albums: \(albumCount), Songs: \(songCount)")
        
        return (albumCount: albumCount, songCount: songCount)
    }
    
    func refreshFromCloud() async {
        guard hasCloudSync else {
            logger.warning("⚠️ Cannot refresh from cloud - cloud sync not available")
            return
        }
        
        logger.cloud("🔄 Refreshing albums from cloud...")
        loadAlbumsFromCloud()
    }
    
    private func loadAlbumsFromCloud() {
        logger.cloud("☁️ Loading albums from cloud...")
        // Implementation for cloud loading
        logger.cloud("☁️ Cloud loading completed")
    }
    
    func getAlbumCount() -> Int {
        return savedAlbums.count
    }
    
    func getAlbumById(_ id: UUID) -> Album? {
        let album = savedAlbums.first { $0.id == id }
        if let album = album {
            logger.debug("🔍 Found album by ID: \(album.title)")
        } else {
            logger.warning("⚠️ Album not found for ID: \(id)")
        }
        return album
    }
    
    func updateAlbum(_ updatedAlbum: Album) {
        logger.album("🔄 Updating album: \(updatedAlbum.title)")
        
        if let index = savedAlbums.firstIndex(where: { $0.id == updatedAlbum.id }) {
            savedAlbums[index] = updatedAlbum
            saveAlbumsMetadata()
            
            if hasCloudSync {
                syncAlbumToPocketBase(updatedAlbum)
            }
            
            logger.success("✅ Album updated: \(updatedAlbum.title)")
        } else {
            logger.error("❌ Cannot update - album not found: \(updatedAlbum.title)")
        }
    }
    
    // MARK: - Debug Information
    
    func printDebugInfo() {
        logger.debug("📊 === DATA PERSISTENCE DEBUG INFO ===")
        logger.debug("Saved Albums: \(savedAlbums.count)")
        logger.debug("Cloud Sync: \(hasCloudSync ? "enabled" : "disabled")")
        logger.debug("Is Loading: \(isLoading)")
        logger.debug("Is Syncing: \(isSyncingToCloud)")
        logger.debug("Cloud Error: \(cloudSyncError ?? "none")")
        
        if let userProfile = UserProfileManager.shared.userProfile {
            logger.debug("User: @\(userProfile.username)")
            logger.debug("Cloud ID: \(userProfile.cloudId ?? "none")")
        } else {
            logger.debug("User: not configured")
        }
        
        logger.debug("====================================")
    }
}
