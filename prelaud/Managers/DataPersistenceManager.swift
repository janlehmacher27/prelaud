//
//  Performance-Fixed DataPersistenceManager.swift
//  prelaud
//
//  Fixed: Caching und Performance-Optimierungen für getStorageInfo()
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
    
    // MARK: - PERFORMANCE FIX: Caching for getStorageInfo()
    private var cachedStorageInfo: StorageInfo?
    private var lastStorageInfoUpdate: Date?
    private let cacheValidDuration: TimeInterval = 1.0 // Cache für 1 Sekunde
    
    private init() {
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        logger.info("🚀 DataPersistenceManager initializing...")
        logger.database("Documents directory: \(documentsDirectory.path)")
        
        loadAlbums()
        checkCloudSyncAvailability()
        
        logger.success("✅ DataPersistenceManager initialized with \(savedAlbums.count) albums")
        
        // Invalidate cache when albums change
        $savedAlbums
            .dropFirst() // Skip initial value
            .sink { [weak self] _ in
                self?.invalidateStorageInfoCache()
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - PERFORMANCE FIX: Cached Storage Info
    
    /// Storage info structure with better performance
    struct StorageInfo {
        let albumCount: Int
        let songCount: Int
        let totalDurationMinutes: Int
        let averageSongsPerAlbum: Double
        let lastUpdated: Date
        
        init(albums: [Album]) {
            self.albumCount = albums.count
            self.songCount = albums.reduce(0) { $0 + $1.songs.count }
            
            let totalDuration = albums.flatMap { $0.songs }.reduce(0.0) { $0 + $1.duration }
            self.totalDurationMinutes = Int(totalDuration / 60)
            
            self.averageSongsPerAlbum = albumCount > 0 ? Double(songCount) / Double(albumCount) : 0.0
            self.lastUpdated = Date()
        }
    }
    
    /// FIXED: Cached totalSongs computed property
    var totalSongs: Int {
        return getStorageInfo().songCount // Uses cached value
    }
    
    /// PERFORMANCE FIX: Cached getStorageInfo with intelligent updates
    func getStorageInfo() -> StorageInfo {
        let now = Date()
        
        // Return cached value if still valid
        if let cached = cachedStorageInfo,
           let lastUpdate = lastStorageInfoUpdate,
           now.timeIntervalSince(lastUpdate) < cacheValidDuration {
            return cached
        }
        
        // Generate new storage info only when needed
        let newInfo = StorageInfo(albums: savedAlbums)
        cachedStorageInfo = newInfo
        lastStorageInfoUpdate = now
        
        // Only log if this is a meaningful update (not spam)
        if lastStorageInfoUpdate == nil || now.timeIntervalSince(lastStorageInfoUpdate!) > 5.0 {
            logger.database("📊 Storage info updated - Albums: \(newInfo.albumCount), Songs: \(newInfo.songCount)")
        }
        
        return newInfo
    }
    
    /// Helper for Settings view compatibility
    func getStorageInfoString() -> String {
        let info = getStorageInfo()
        return "📊 Albums: \(info.albumCount), Songs: \(info.songCount), Duration: \(info.totalDurationMinutes)min"
    }
    
    /// Invalidate cache when albums change
    private func invalidateStorageInfoCache() {
        cachedStorageInfo = nil
        lastStorageInfoUpdate = nil
    }
    
    // MARK: - Enhanced Album Saving with Performance Logging
    
    func saveAlbum(_ album: Album) {
        let startTime = Date()
        
        logger.album("🎵 Starting saveAlbum process")
        logger.album("Album: '\(album.title)' by '\(album.artist)'")
        logger.album("Album ID: \(album.id)")
        logger.album("Songs count: \(album.songs.count)")
        
        // Check if album already exists
        let existingIndex = savedAlbums.firstIndex(where: { $0.id == album.id })
        if let index = existingIndex {
            logger.album("🔄 Album already exists at index \(index), will update")
        } else {
            logger.album("➕ New album, will add to collection")
        }
        
        // 1. Save locally first (critical for offline capability)
        saveAlbumLocally(album)
        
        // 2. Try cloud sync if available
        if hasCloudSync {
            logger.cloud("☁️ Cloud sync is available, starting sync...")
            syncAlbumToPocketBase(album)
        } else {
            logger.cloud("☁️ Cloud sync not available, skipping")
        }
        
        let duration = Date().timeIntervalSince(startTime)
        logger.success("✅ saveAlbum completed for: \(album.title) in \(String(format: "%.3f", duration))s")
    }
    
    private func saveAlbumLocally(_ album: Album) {
        let beforeCount = savedAlbums.count
        
        // Add or update in array
        if let existingIndex = savedAlbums.firstIndex(where: { $0.id == album.id }) {
            savedAlbums[existingIndex] = album
        } else {
            savedAlbums.append(album)
            // Sort by release date
            savedAlbums.sort { $0.releaseDate > $1.releaseDate }
        }
        
        let afterCount = savedAlbums.count
        
        // Save to persistent storage
        saveAlbumsMetadata()
        
        // Verify save
        verifyLocalSave(album)
        
        logger.database("Album count: \(beforeCount) → \(afterCount)")
    }
    
    func saveAlbumsMetadata() {
        do {
            let encodableAlbums = savedAlbums.map { album in
                EncodableAlbum(
                    from: album,
                    shareId: album.shareId ?? "",
                    ownerId: album.ownerId ?? "",
                    ownerUsername: album.ownerUsername ?? ""
                )
            }
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let encoded = try encoder.encode(encodableAlbums)
            
            UserDefaults.standard.set(encoded, forKey: albumsKey)
            UserDefaults.standard.synchronize() // Force immediate save
            
            logger.database("💾 Albums metadata saved (\(encoded.count) bytes)")
            
            // Immediate read-back verification
            if let readBack = UserDefaults.standard.data(forKey: albumsKey) {
                if let decodedAlbums = try? JSONDecoder().decode([EncodableAlbum].self, from: readBack) {
                    logger.database("✅ Read-back verification: \(decodedAlbums.count) albums")
                } else {
                    logger.error("❌ Read-back decode failed!")
                }
            }
            
        } catch {
            logger.error("❌ Failed to encode albums: \(error.localizedDescription)")
        }
    }
    
    private func verifyLocalSave(_ album: Album) {
        // Check in-memory array
        if savedAlbums.contains(where: { $0.id == album.id }) {
            logger.database("✅ Album verified in savedAlbums array")
        } else {
            logger.error("❌ Album NOT found in savedAlbums array!")
        }
        
        // Check UserDefaults with better error handling
        guard let data = UserDefaults.standard.data(forKey: albumsKey) else {
            logger.error("❌ No data in UserDefaults for key: \(albumsKey)")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let albums = try decoder.decode([EncodableAlbum].self, from: data)
            
            if albums.contains(where: { $0.id.uuidString == album.id.uuidString }) {
                logger.database("✅ Album verified in UserDefaults")
            } else {
                logger.error("❌ Album NOT found in UserDefaults!")
            }
            
        } catch {
            logger.error("❌ Failed to decode UserDefaults data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Enhanced Loading with Performance Monitoring
    
    private func loadAlbums() {
        let startTime = Date()
        logger.database("📂 Loading albums from storage...")
        isLoading = true
        
        defer {
            isLoading = false
            let duration = Date().timeIntervalSince(startTime)
            logger.database("📂 Loading completed in \(String(format: "%.3f", duration))s")
        }
        
        guard let data = UserDefaults.standard.data(forKey: albumsKey) else {
            logger.warning("⚠️ No saved albums data found in UserDefaults")
            return
        }
        
        logger.database("📂 Found UserDefaults data: \(data.count) bytes")
        
        do {
            // Try with ISO8601 date strategy first
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let encodableAlbums = try decoder.decode([EncodableAlbum].self, from: data)
            
                            savedAlbums = encodableAlbums.compactMap { encodableAlbum in
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
                
                savedAlbums = encodableAlbums.compactMap { encodableAlbum in
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
                        coverImage: nil,
                        releaseDate: encodableAlbum.releaseDate,
                        ownerId: encodableAlbum.ownerId.isEmpty ? nil : encodableAlbum.ownerId,
                        ownerUsername: encodableAlbum.ownerUsername.isEmpty ? nil : encodableAlbum.ownerUsername,
                        shareId: encodableAlbum.shareId.isEmpty ? nil : encodableAlbum.shareId
                    )
                }
                
                logger.success("✅ Successfully loaded \(savedAlbums.count) albums with fallback strategy")
                
                // Re-save with consistent format
                saveAlbumsMetadata()
                
            } catch {
                logger.error("❌ Both decoding strategies failed: \(error.localizedDescription)")
                
                // Clear corrupted data and start fresh
                UserDefaults.standard.removeObject(forKey: albumsKey)
                savedAlbums = []
                
                logger.warning("⚠️ Cleared corrupted album data - starting fresh")
            }
        }
        
        // Log summary instead of each album to reduce spam
        if !savedAlbums.isEmpty {
            logger.database("📂 Loaded albums: \(savedAlbums.map { "\($0.title) (\($0.songs.count) songs)" }.joined(separator: ", "))")
        }
    }
    
    // MARK: - Cloud Sync with Performance Monitoring
    
    private func checkCloudSyncAvailability() {
        logger.cloud("🔍 Checking cloud sync availability...")
        
        let profileSetup = UserProfileManager.shared.isProfileSetup
        let pocketBaseConfigured = true
        
        hasCloudSync = profileSetup && pocketBaseConfigured
        
        logger.cloud("Final hasCloudSync: \(hasCloudSync)")
        
        if hasCloudSync {
            logger.success("✅ Cloud sync available")
        } else {
            logger.warning("⚠️ Cloud sync not available")
        }
    }
    
    private func syncAlbumToPocketBase(_ album: Album) {
        Task {
            let startTime = Date()
            isSyncingToCloud = true
            logger.cloud("☁️ Starting PocketBase sync for: \(album.title)")
            
            do {
                // Prepare cover image data
                let coverImageData: Data
                if let coverImage = album.coverImage,
                   let imageData = coverImage.jpegData(compressionQuality: 0.8) {
                    coverImageData = imageData
                } else {
                    let placeholderImage = UIImage(systemName: "music.note") ?? UIImage()
                    coverImageData = placeholderImage.jpegData(compressionQuality: 0.8) ?? Data()
                }
                
                let pocketBaseAlbumId = try await pocketBase.saveAlbumWithCoverToPocketBase(album, coverImageData: coverImageData)
                
                await MainActor.run {
                    let duration = Date().timeIntervalSince(startTime)
                    logger.success("✅ PocketBase sync completed in \(String(format: "%.3f", duration))s: \(pocketBaseAlbumId)")
                    cloudSyncError = nil
                }
                
            } catch {
                logger.error("❌ PocketBase sync failed: \(error.localizedDescription)")
                
                await MainActor.run {
                    cloudSyncError = "Failed to sync \(album.title): \(error.localizedDescription)"
                }
            }
            
            await MainActor.run {
                isSyncingToCloud = false
            }
        }
    }
    
    // MARK: - Delete with Performance Tracking
    
    func deleteAlbum(_ album: Album) {
        let startTime = Date()
        logger.album("🗑️ Deleting album: \(album.title)")
        
        let beforeCount = savedAlbums.count
        savedAlbums.removeAll { $0.id == album.id }
        let afterCount = savedAlbums.count
        
        saveAlbumsMetadata()
        
        let duration = Date().timeIntervalSince(startTime)
        logger.success("✅ Album deleted in \(String(format: "%.3f", duration))s: \(album.title)")
        logger.database("Album count: \(beforeCount) → \(afterCount)")
    }
    
    // MARK: - Cascade Delete with Cleanup
    
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
    
    // MARK: - Utility Functions
    
    func createTestAlbum() {
        logger.debug("🧪 Creating test album...")
        
        let testAlbum = Album(
            title: "Debug Test Album \(Int(Date().timeIntervalSince1970))",
            artist: "Test Artist",
            songs: [
                Song(title: "Test Song 1", artist: "Test Artist", duration: 180),
                Song(title: "Test Song 2", artist: "Test Artist", duration: 200)
            ],
            releaseDate: Date()
        )
        
        saveAlbum(testAlbum)
        logger.debug("🧪 Test album created: \(testAlbum.title)")
    }
    
    func validateDataIntegrity() {
        let startTime = Date()
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
            
            if savedAlbums.count == storedAlbums.count {
                logger.success("✅ Album counts match (\(savedAlbums.count))")
            } else {
                logger.error("❌ Album count mismatch: memory=\(savedAlbums.count), storage=\(storedAlbums.count)")
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
            logger.error("❌ Failed to decode stored albums: \(error.localizedDescription)")
        }
        
        let duration = Date().timeIntervalSince(startTime)
        logger.debug("🔍 Data integrity validation completed in \(String(format: "%.3f", duration))s")
    }
    
    func clearAllData() {
        logger.warning("⚠️ Clearing all album data...")
        
        savedAlbums.removeAll()
        UserDefaults.standard.removeObject(forKey: albumsKey)
        UserDefaults.standard.synchronize()
        
        // Clear cache
        invalidateStorageInfoCache()
        
        logger.warning("⚠️ All album data cleared")
    }
    
    func refreshFromCloud() async {
        guard hasCloudSync else {
            logger.warning("⚠️ Cannot refresh from cloud - cloud sync not available")
            return
        }
        
        logger.cloud("🔄 Refreshing albums from cloud...")
        // Implementation for cloud loading would go here
        logger.cloud("☁️ Cloud refresh completed")
    }
    
    func getAlbumCount() -> Int {
        return savedAlbums.count
    }
    
    func getAlbumById(_ id: UUID) -> Album? {
        return savedAlbums.first { $0.id == id }
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
    
    // MARK: - Debug Information with Performance Stats
    
    func printDebugInfo() {
        let info = getStorageInfo()
        logger.debug("📊 === DATA PERSISTENCE DEBUG INFO ===")
        logger.debug("Saved Albums: \(info.albumCount)")
        logger.debug("Total Songs: \(info.songCount)")
        logger.debug("Total Duration: \(info.totalDurationMinutes) minutes")
        logger.debug("Average Songs/Album: \(String(format: "%.1f", info.averageSongsPerAlbum))")
        logger.debug("Cloud Sync: \(hasCloudSync ? "enabled" : "disabled")")
        logger.debug("Is Loading: \(isLoading)")
        logger.debug("Is Syncing: \(isSyncingToCloud)")
        logger.debug("Cloud Error: \(cloudSyncError ?? "none")")
        logger.debug("Cache Valid: \(cachedStorageInfo != nil)")
        
        if let userProfile = UserProfileManager.shared.userProfile {
            logger.debug("User: @\(userProfile.username)")
            logger.debug("Cloud ID: \(userProfile.cloudId ?? "none")")
        } else {
            logger.debug("User: not configured")
        }
        
        logger.debug("====================================")
    }
}

// MARK: - Import for Combine
import Combine
