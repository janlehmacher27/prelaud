//
//  AlbumSharingManager.swift - FIXED FOR POCKETBASE INTEGRATION
//  prelaud
//
//  Fixed PBUser optional handling and integrated with new PocketBase setup
//

import Foundation
import SwiftUI

@MainActor
class AlbumSharingManager: ObservableObject {
    static let shared = AlbumSharingManager()
    
    @Published var sharedWithMeAlbums: [Album] = []
    @Published var isLoadingSharedAlbums = false
    @Published var sharingError: String?
    
    private let pocketBase = PocketBaseManager.shared
    
    private init() {
        loadSharedAlbums()
        setupDeleteNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Delete Notifications Setup
    
    func setupDeleteNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AlbumDeleted"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let shareId = notification.userInfo?["shareId"] as? String {
                Task { @MainActor in
                    self?.handleAlbumDeleted(shareId: shareId)
                }
            }
        }
    }
    
    private func handleAlbumDeleted(shareId: String) {
        print("📢 Received album deleted notification for shareId: \(shareId)")
        
        // Remove from shared albums list
        sharedWithMeAlbums.removeAll { $0.shareId == shareId }
        
        // Clean up local storage
        UserDefaults.standard.removeObject(forKey: "SharedAlbumData_\(shareId)")
        UserDefaults.standard.removeObject(forKey: "SharedAlbum_\(shareId)")
        
        print("✅ Removed deleted album from shared gallery")
    }
    
    // MARK: - Album Sharing
    
    func shareAlbum(_ album: Album, withUsername targetUsername: String) async throws -> String {
        guard let currentUser = UserProfileManager.shared.userProfile else {
            throw SharingError.notLoggedIn
        }
        
        print("📤 Sharing album: \(album.title) with @\(targetUsername)")
        
        // 1. Find target user - FIXED: Handle optional properly
        guard let targetUser = try await pocketBase.getUserByUsername(targetUsername) else {
            print("❌ Target user not found: @\(targetUsername)")
            throw SharingError.userNotFound
        }
        
        print("✅ Found target user: @\(targetUser.username)")
        
        // 2. Generate share ID
        let shareId = "share_\(UUID().uuidString.prefix(12))"
        
        // 3. Store shared album locally (temporary until full PocketBase integration)
        var sharedAlbum = album
        sharedAlbum.shareId = shareId
        sharedAlbum.ownerId = currentUser.id.uuidString
        sharedAlbum.ownerUsername = currentUser.username
        
        // 4. Save to UserDefaults for now
        let encodableAlbum = EncodableAlbum(
            from: sharedAlbum,
            shareId: shareId,
            ownerId: currentUser.id.uuidString,
            ownerUsername: currentUser.username
        )
        
        if let encoded = try? JSONEncoder().encode(encodableAlbum) {
            UserDefaults.standard.set(encoded, forKey: "SharedAlbum_\(shareId)")
            print("✅ Shared album stored locally: \(shareId)")
        }
        
        // 5. In the future, create sharing request in PocketBase here
        // For now, just return the shareId
        
        return shareId
    }
    
    // MARK: - Load Shared Albums
    
    func loadSharedAlbums() {
        guard UserProfileManager.shared.userProfile != nil else {
            print("⚠️ No user profile - cannot load shared albums")
            return
        }
        
        Task {
            isLoadingSharedAlbums = true
            
            do {
                // Load shared albums from local storage (temporary)
                var albums: [Album] = []
                
                let defaults = UserDefaults.standard
                for key in defaults.dictionaryRepresentation().keys {
                    if key.hasPrefix("SharedAlbum_") || key.hasPrefix("SharedAlbumData_") {
                        if let data = defaults.data(forKey: key) {
                            do {
                                let encodableAlbum = try JSONDecoder().decode(EncodableAlbum.self, from: data)
                                let album = encodableAlbum.toAlbum()
                                albums.append(album)
                                print("📂 Loaded shared album: \(album.title)")
                            } catch {
                                print("⚠️ Failed to decode shared album from key: \(key)")
                            }
                        }
                    }
                }
                
                await MainActor.run {
                    sharedWithMeAlbums = albums
                    isLoadingSharedAlbums = false
                    sharingError = nil
                    print("✅ Loaded \(albums.count) shared albums")
                }
                
            } catch {
                await MainActor.run {
                    sharingError = "Failed to load shared albums: \(error.localizedDescription)"
                    isLoadingSharedAlbums = false
                    print("❌ Error loading shared albums: \(error)")
                }
            }
        }
    }
    
    // MARK: - Album Management
    
    func removeSharedAlbum(shareId: String) async throws {
        print("🗑️ Removing shared album: \(shareId)")
        
        // Remove from local storage
        UserDefaults.standard.removeObject(forKey: "SharedAlbum_\(shareId)")
        UserDefaults.standard.removeObject(forKey: "SharedAlbumData_\(shareId)")
        
        // Remove from UI
        sharedWithMeAlbums.removeAll { $0.shareId == shareId }
        
        print("✅ Shared album removed: \(shareId)")
    }
    
    func refreshSharedAlbums() {
        print("🔄 Refreshing shared albums...")
        loadSharedAlbums()
    }
    
    func getSharedAlbumCount() -> Int {
        return sharedWithMeAlbums.count
    }
    
    func getSharedAlbum(by shareId: String) -> Album? {
        return sharedWithMeAlbums.first { $0.shareId == shareId }
    }
    
    func clearAllSharedAlbums() {
        print("🧹 Clearing all shared albums...")
        
        // Clear from memory
        sharedWithMeAlbums.removeAll()
        
        // Clear from local storage
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix("SharedAlbum_") || key.hasPrefix("SharedAlbumData_") {
                defaults.removeObject(forKey: key)
                print("🗑️ Removed: \(key)")
            }
        }
        
        print("✅ All shared albums cleared")
    }
    
    // MARK: - Integration with PocketBase (Future Implementation)
    
    func createSharingRequest(_ album: Album, targetUsername: String, permissions: SharePermissions) async throws {
        // This will integrate with PocketBaseSharingManager in the future
        // For now, use the simpler shareAlbum method
        _ = try await shareAlbum(album, withUsername: targetUsername)
    }
    
    func loadSharingRequests() async throws -> [SharingRequest] {
        // Future implementation: load from PocketBase
        // For now, return empty array
        return []
    }
    
    // MARK: - Debug Methods
    
    func printDebugInfo() {
        print("📊 AlbumSharingManager Debug Info:")
        print("  - Shared Albums: \(sharedWithMeAlbums.count)")
        print("  - Is Loading: \(isLoadingSharedAlbums)")
        print("  - Error: \(sharingError ?? "none")")
        
        if let userProfile = UserProfileManager.shared.userProfile {
            print("  - User: @\(userProfile.username)")
            print("  - CloudId: \(userProfile.cloudId ?? "missing")")
        } else {
            print("  - No user profile")
        }
        
        // List all shared albums
        for album in sharedWithMeAlbums {
            print("  - Album: \(album.title) (shareId: \(album.shareId ?? "none"))")
        }
    }
}

// MARK: - Sharing Errors
