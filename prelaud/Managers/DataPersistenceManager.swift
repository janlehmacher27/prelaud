//
//  DataPersistenceManager.swift - COMPLETELY FIXED VERSION
//  prelaud
//
//  All compilation errors resolved, missing methods added, correct API calls
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
    
    private init() {
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        loadAlbums()
        
        // Check if user has PocketBase setup
        checkCloudSyncAvailability()
    }
    
    func getStorageInfo() -> (albumCount: Int, songCount: Int) {
        let albumCount = savedAlbums.count
        let songCount = savedAlbums.reduce(0) { $0 + $1.songs.count }
        return (albumCount: albumCount, songCount: songCount)
    }
    
    // MARK: - Enhanced Album Saving with PocketBase
    
    func saveAlbum(_ album: Album) {
        print("💾 Saving album with PocketBase sync: \(album.title)")
        
        // 1. Save locally first (for offline capability)
        saveAlbumLocally(album)
        
        // 2. Try to sync to PocketBase if available
        if hasCloudSync {
            syncAlbumToPocketBase(album)
        }
    }
    
    private func saveAlbumLocally(_ album: Album) {
        // Add to local array
        if !savedAlbums.contains(where: { $0.id == album.id }) {
            savedAlbums.append(album)
            savedAlbums.sort { $0.releaseDate > $1.releaseDate }
        } else {
            // Update existing album
            if let index = savedAlbums.firstIndex(where: { $0.id == album.id }) {
                savedAlbums[index] = album
            }
        }
        
        // Save to persistent storage
        saveAlbumsMetadata()
        
        print("✅ Album saved locally: \(album.title)")
    }
    
    private func syncAlbumToPocketBase(_ album: Album) {
        Task {
            isSyncingToCloud = true
            
            do {
                // FIXED: Provide cover image data or use placeholder
                let coverImageData: Data
                if let coverImage = album.coverImage,
                   let imageData = coverImage.jpegData(compressionQuality: 0.8) {
                    coverImageData = imageData
                } else {
                    // Create a small placeholder image data if no cover image
                    let placeholderImage = UIImage(systemName: "music.note") ?? UIImage()
                    coverImageData = placeholderImage.jpegData(compressionQuality: 0.8) ?? Data()
                }
                
                let pocketBaseAlbumId = try await pocketBase.saveAlbumWithCoverToPocketBase(album, coverImageData: coverImageData)
                
                print("✅ Album synced to PocketBase: \(pocketBaseAlbumId)")
                
                cloudSyncError = nil
                
            } catch {
                cloudSyncError = "Failed to sync album to cloud: \(error.localizedDescription)"
                print("❌ Failed to sync album to PocketBase: \(error)")
            }
            
            isSyncingToCloud = false
        }
    }
    
    // MARK: - Album Loading
    
    func loadAlbums() {
        print("📂 Loading albums...")
        
        // Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: albumsKey),
           let decodedAlbums = try? JSONDecoder().decode([EncodableAlbum].self, from: data) {
            savedAlbums = decodedAlbums.map { $0.toAlbum() }
            print("✅ Loaded \(savedAlbums.count) albums from local storage")
        }
        
        // Try to load from cloud if available
        if hasCloudSync {
            loadAlbumsFromCloud()
        }
    }
    
    private func loadAlbumsFromCloud() {
        Task {
            isLoading = true
            
            do {
                let cloudAlbums = try await pocketBase.loadAlbumsFromPocketBase()
                
                await MainActor.run {
                    mergeCloudAlbums(cloudAlbums)
                    isLoading = false
                    print("✅ Merged \(cloudAlbums.count) cloud albums")
                }
                
            } catch {
                await MainActor.run {
                    cloudSyncError = "Failed to load albums from cloud: \(error.localizedDescription)"
                    isLoading = false
                    print("❌ Failed to load albums from PocketBase: \(error)")
                }
            }
        }
    }
    
    private func mergeCloudAlbums(_ cloudAlbums: [Album]) {
        for cloudAlbum in cloudAlbums {
            // Check if we already have this album locally
            if !savedAlbums.contains(where: { $0.title == cloudAlbum.title && $0.artist == cloudAlbum.artist }) {
                savedAlbums.append(cloudAlbum)
            }
        }
        
        // Sort by release date (newest first)
        savedAlbums.sort { $0.releaseDate > $1.releaseDate }
    }
    
    // MARK: - Album Deletion with Cascade Delete
    
    func deleteAlbum(_ album: Album) {
        print("🗑️ Starting enhanced delete for album: \(album.title)")
        
        Task {
            await cascadeDeleteAlbum(album)
        }
    }
    
    // FIXED: Added missing cascadeDeleteAlbum method
    func cascadeDeleteAlbum(_ album: Album) async {
        print("🗑️ Starting cascade delete process for album: \(album.title)")
        
        // Step 1: Remove from local array immediately (UI responsiveness)
        await MainActor.run {
            savedAlbums.removeAll { $0.id == album.id }
        }
        
        // Step 2: Save updated local state
        saveAlbumsMetadata()
        
        // Step 3: Perform cascade delete in PocketBase
        if hasCloudSync {
            do {
                try await pocketBase.cascadeDeleteAlbum(album)
                print("✅ Cascade delete completed successfully")
            } catch {
                await MainActor.run {
                    cloudSyncError = "Failed to completely delete album from cloud: \(error.localizedDescription)"
                }
                print("❌ Cascade delete failed: \(error)")
            }
        }
        
        // Step 4: Notify sharing manager to update UI
        await MainActor.run {
            if let shareId = album.shareId {
                NotificationCenter.default.post(
                    name: NSNotification.Name("AlbumDeleted"),
                    object: nil,
                    userInfo: ["shareId": shareId, "albumId": album.id.uuidString]
                )
            }
        }
        
        print("✅ Cascade delete process completed for: \(album.title)")
    }
    
    private func deleteAlbumFromPocketBase(_ album: Album) {
        // Note: This requires knowing the PocketBase album ID
        // For now, we'll implement a search-and-delete approach
        Task {
            do {
                // First, find the album in PocketBase by title and artist
                let cloudAlbums = try await pocketBase.loadAlbumsFromPocketBase()
                
                // FIXED: Use contains(where:) instead of storing unused variable
                if cloudAlbums.contains(where: {
                    $0.title == album.title && $0.artist == album.artist
                }) {
                    // Album found in cloud - would need PocketBase album ID to delete
                    // This is a limitation of the current implementation
                    print("⚠️ Album found in cloud but cannot delete without PocketBase album ID")
                }
                
            } catch {
                print("❌ Failed to find album in PocketBase for deletion: \(error)")
            }
        }
    }
    
    // MARK: - Cloud Sync Management
    
    private func checkCloudSyncAvailability() {
        Task {
            // FIXED: Use correct method name
            let isConnected = await pocketBase.testConnection()
            
            await MainActor.run {
                hasCloudSync = isConnected && UserProfileManager.shared.userProfile?.cloudId != nil
                
                if hasCloudSync {
                    print("✅ Cloud sync available")
                } else {
                    print("⚠️ Cloud sync not available - \(isConnected ? "no user profile" : "no connection")")
                }
            }
        }
    }
    
    func enableCloudSync() async {
        print("🔄 Enabling cloud sync...")
        
        // Check connection and user setup
        checkCloudSyncAvailability()
        
        if hasCloudSync {
            // Sync existing albums to cloud
            await syncAllAlbumsToCloud()
            
            // Load any missing albums from cloud
            loadAlbumsFromCloud()
        }
    }
    
    private func syncAllAlbumsToCloud() async {
        print("☁️ Syncing all albums to cloud...")
        
        isSyncingToCloud = true
        
        for album in savedAlbums {
            do {
                // FIXED: Provide cover image data
                let coverImageData: Data
                if let coverImage = album.coverImage,
                   let imageData = coverImage.jpegData(compressionQuality: 0.8) {
                    coverImageData = imageData
                } else {
                    // Create a small placeholder image data if no cover image
                    let placeholderImage = UIImage(systemName: "music.note") ?? UIImage()
                    coverImageData = placeholderImage.jpegData(compressionQuality: 0.8) ?? Data()
                }
                
                let pocketBaseAlbumId = try await pocketBase.saveAlbumWithCoverToPocketBase(album, coverImageData: coverImageData)
                print("✅ Synced album: \(album.title) -> \(pocketBaseAlbumId)")
                
            } catch {
                print("❌ Failed to sync album \(album.title): \(error)")
                
                await MainActor.run {
                    cloudSyncError = "Failed to sync some albums: \(error.localizedDescription)"
                }
            }
        }
        
        isSyncingToCloud = false
        print("✅ Cloud sync completed")
    }
    
    // MARK: - Persistent Storage
    
     func saveAlbumsMetadata() {
        let encodableAlbums = savedAlbums.map { album in
            EncodableAlbum(
                from: album,
                shareId: album.shareId ?? "",
                ownerId: album.ownerId ?? "",
                ownerUsername: album.ownerUsername ?? ""
            )
        }
        
        if let encoded = try? JSONEncoder().encode(encodableAlbums) {
            UserDefaults.standard.set(encoded, forKey: albumsKey)
            print("💾 Albums metadata saved to UserDefaults")
        } else {
            print("❌ Failed to encode albums for saving")
        }
    }
    
    // MARK: - Debug and Utilities
    
    func refreshFromCloud() async {
        guard hasCloudSync else {
            print("⚠️ Cloud sync not available")
            return
        }
        
        print("🔄 Refreshing albums from cloud...")
        loadAlbumsFromCloud()
    }
    
    func getAlbumCount() -> Int {
        return savedAlbums.count
    }
    
    func getAlbumById(_ id: UUID) -> Album? {
        return savedAlbums.first { $0.id == id }
    }
    
    func updateAlbum(_ updatedAlbum: Album) {
        if let index = savedAlbums.firstIndex(where: { $0.id == updatedAlbum.id }) {
            savedAlbums[index] = updatedAlbum
            saveAlbumsMetadata()
            
            // Sync update to cloud if available
            if hasCloudSync {
                syncAlbumToPocketBase(updatedAlbum)
            }
            
            print("✅ Album updated: \(updatedAlbum.title)")
        }
    }
    
    // MARK: - Debug Information
    
    func printDebugInfo() {
        print("📊 DataPersistenceManager Debug Info:")
        print("  - Saved Albums: \(savedAlbums.count)")
        print("  - Cloud Sync: \(hasCloudSync ? "enabled" : "disabled")")
        print("  - Is Loading: \(isLoading)")
        print("  - Is Syncing: \(isSyncingToCloud)")
        print("  - Cloud Error: \(cloudSyncError ?? "none")")
        
        if let userProfile = UserProfileManager.shared.userProfile {
            print("  - User: @\(userProfile.username)")
            print("  - Cloud ID: \(userProfile.cloudId ?? "none")")
        } else {
            print("  - No user profile")
        }
    }
}
