//
//  DatabaseSyncManager.swift - FIXED USER VALIDATION (NO CONFLICTS)
//  prelaud
//
//  Enhanced validation with automatic cloudId fixing - no method conflicts
//

import Foundation
import SwiftUI

@MainActor
class DatabaseSyncManager: ObservableObject {
    static let shared = DatabaseSyncManager()
    
    @Published var isSyncing = false
    @Published var syncStatus = "Checking database..."
    @Published var needsSetup = false
    @Published var syncComplete = false
    
    private let pocketBase = PocketBaseManager.shared
    private let userManager = UserProfileManager.shared
    private let dataManager = DataPersistenceManager.shared
    
    private init() {}
    
    // MARK: - Main Sync Check (Enhanced with CloudId Fixing)
    
    func performStartupSync() async {
        print("🔄 Starting enhanced database sync check...")
        
        isSyncing = true
        syncComplete = false
        needsSetup = false
        
        // 1. Test connection first
        syncStatus = "Checking connection..."
        let isConnected = await pocketBase.performHealthCheck()
        
        guard isConnected else {
            print("❌ No database connection - using offline mode")
            syncStatus = "Offline mode"
            isSyncing = false
            syncComplete = true
            return
        }
        
        print("✅ Database connection established")
        
        // 2. Enhanced user validation with auto-fix
        syncStatus = "Validating user..."
        let userValid = await validateUserProfileWithAutoFix()
        
        if !userValid {
            print("❌ User validation failed after auto-fix attempt - forcing setup")
            needsSetup = true
            syncStatus = "Setup required"
            isSyncing = false
            return
        }
        
        // 3. Check albums sync
        syncStatus = "Syncing albums..."
        await validateAndSyncAlbums()
        
        // 4. Complete
        syncStatus = "Sync complete"
        isSyncing = false
        syncComplete = true
        
        print("✅ Enhanced database sync check complete")
    }
    
    // MARK: - Enhanced User Profile Validation with Auto-Fix
    
    private func validateUserProfileWithAutoFix() async -> Bool {
        // Check if profile exists locally
        guard let localProfile = userManager.userProfile else {
            print("⚠️ No local user profile found")
            return false
        }
        
        // Check if cloudId is missing
        if localProfile.cloudId == nil {
            print("🔧 CloudId missing - attempting auto-fix...")
            syncStatus = "Fixing user profile..."
            
            let fixResult = await userManager.fixMissingCloudId()
            if !fixResult {
                print("❌ Failed to fix missing cloudId")
                return false
            }
            
            print("✅ CloudId fixed successfully")
        }
        
        // Now validate with PocketBase
        guard let cloudId = userManager.userProfile?.cloudId else {
            print("❌ Still no cloudId after fix attempt")
            return false
        }
        
        print("🔍 Validating user: @\(localProfile.username) (ID: \(cloudId))")
        
        do {
            // Check if user exists in database
            let cloudUser = try await pocketBase.getUserById(cloudId)
            
            // Verify username matches
            if cloudUser.username != localProfile.username {
                print("❌ Username mismatch: local=@\(localProfile.username), cloud=@\(cloudUser.username)")
                
                // Try to fix username mismatch
                print("🔧 Attempting to fix username mismatch...")
                await updateLocalProfileFromCloud(cloudUser)
                
                // Re-validate after fix
                if let updatedProfile = userManager.userProfile,
                   updatedProfile.username == cloudUser.username {
                    print("✅ Username mismatch fixed")
                } else {
                    print("❌ Failed to fix username mismatch - clearing data")
                    clearLocalUserData()
                    return false
                }
            }
            
            // Update local profile with latest cloud data if needed
            if cloudUser.artistName != localProfile.artistName ||
               cloudUser.bio != localProfile.bio {
                print("🔄 Updating local profile with cloud data")
                await updateLocalProfileFromCloud(cloudUser)
            }
            
            print("✅ User profile validated: @\(cloudUser.username)")
            return true
            
        } catch {
            print("❌ User validation failed: \(error)")
            
            // Enhanced error handling
            if let pbError = error as? PBError {
                switch pbError {
                case .userNotFound:
                    print("🔧 User not found in database - attempting to recreate...")
                    return await attemptUserRecreation(localProfile)
                case .networkError:
                    print("🌐 Network error during validation")
                    return false
                default:
                    print("💥 PocketBase error: \(pbError)")
                    return false
                }
            }
            
            // Generic error handling
            if error.localizedDescription.contains("not found") {
                print("🔧 User not found - attempting recreation...")
                return await attemptUserRecreation(localProfile)
            }
            
            return false
        }
    }
    
    // MARK: - User Recreation
    
    private func attemptUserRecreation(_ localProfile: UserProfile) async -> Bool {
        print("🔄 Attempting to recreate user in database...")
        syncStatus = "Recreating user profile..."
        
        do {
            // Create user in PocketBase
            let cloudUser = try await pocketBase.createUser(
                username: localProfile.username,
                artistName: localProfile.artistName,
                bio: localProfile.bio
            )
            
            // Update local profile with new cloudId
            var updatedProfile = localProfile
            updatedProfile.cloudId = cloudUser.id
            userManager.userProfile = updatedProfile
            userManager.saveProfile()
            
            print("✅ User successfully recreated with ID: \(cloudUser.id)")
            return true
            
        } catch {
            print("❌ Failed to recreate user: \(error)")
            
            // If recreation fails, clear local data
            clearLocalUserData()
            return false
        }
    }
    
    // MARK: - Profile Updates
    
    private func updateLocalProfileFromCloud(_ cloudUser: PBUser) async {
        guard var localProfile = userManager.userProfile else { return }
        
        localProfile.username = cloudUser.username
        localProfile.artistName = cloudUser.artistName
        localProfile.bio = cloudUser.bio
        localProfile.updatedAt = Date()
        
        userManager.userProfile = localProfile
        userManager.saveProfile()
        
        print("✅ Local profile updated from cloud")
    }
    
    private func clearLocalUserData() {
        print("🗑️ Clearing local user data")
        
        userManager.userProfile = nil
        userManager.isProfileSetup = false
        
        // Clear stored profile
        UserDefaults.standard.removeObject(forKey: "UserProfile")
        UserDefaults.standard.removeObject(forKey: "IsProfileSetup")
        
        // Clear all albums too since they belong to this user
        dataManager.clearAllLocalData()
    }
    
    // MARK: - Albums Validation and Sync
    
    private func validateAndSyncAlbums() async {
        print("🔍 Validating local albums against database...")
        
        let localAlbums = dataManager.savedAlbums
        guard !localAlbums.isEmpty else {
            print("ℹ️ No local albums to validate")
            return
        }
        
        print("📱 Found \(localAlbums.count) local albums")
        
        do {
            // Get all albums from cloud for current user
            let cloudAlbums = try await pocketBase.loadAlbumsFromPocketBase()
            print("☁️ Found \(cloudAlbums.count) cloud albums")
            
            var albumsToRemove: [Album] = []
            var albumsToUpdate: [Album] = []
            
            // Check each local album
            for localAlbum in localAlbums {
                if let cloudAlbum = findMatchingCloudAlbum(localAlbum, in: cloudAlbums) {
                    // Album exists in cloud - check if songs match
                    if await validateAlbumSongs(localAlbum, cloudAlbum: cloudAlbum) {
                        print("✅ Album validated: \(localAlbum.title)")
                    } else {
                        print("🔄 Album needs song updates: \(localAlbum.title)")
                        albumsToUpdate.append(cloudAlbum)
                    }
                } else {
                    print("❌ Album not found in cloud: \(localAlbum.title)")
                    albumsToRemove.append(localAlbum)
                }
            }
            
            // Apply changes
            for album in albumsToRemove {
                dataManager.deleteAlbumLocally(album)
            }
            
            for album in albumsToUpdate {
                dataManager.updateAlbumLocally(album)
            }
            
            // Add new cloud albums not present locally
            for cloudAlbum in cloudAlbums {
                if !localAlbums.contains(where: { $0.id == cloudAlbum.id }) {
                    dataManager.addAlbumLocally(cloudAlbum)
                }
            }
            
        } catch {
            print("⚠️ Failed to sync albums: \(error)")
        }
    }
    
    private func findMatchingCloudAlbum(_ localAlbum: Album, in cloudAlbums: [Album]) -> Album? {
        return cloudAlbums.first { cloudAlbum in
            cloudAlbum.id == localAlbum.id ||
            (cloudAlbum.title == localAlbum.title && cloudAlbum.artist == localAlbum.artist)
        }
    }
    
    private func validateAlbumSongs(_ localAlbum: Album, cloudAlbum: Album) async -> Bool {
        // Check if song count matches
        guard localAlbum.songs.count == cloudAlbum.songs.count else {
            return false
        }
        
        // Check if all songs have valid audio files
        for song in localAlbum.songs {
            if let songId = song.songId {
                let hasAudio = await audioFileExists(songId: songId)
                if !hasAudio {
                    return false
                }
            }
        }
        
        return true
    }
    
    private func audioFileExists(songId: String) async -> Bool {
        do {
            let audioURL = try await pocketBase.getAudioFileURL(songId: songId)
            return audioURL != nil
        } catch {
            print("⚠️ Failed to check audio file for songId \(songId): \(error)")
            return false
        }
    }
    
    // MARK: - Force Reset Methods
    
    func forceCompleteReset() async {
        print("🔄 Performing complete app reset...")
        
        syncStatus = "Resetting app..."
        isSyncing = true
        
        // Clear all local data
        clearLocalUserData()
        dataManager.clearAllLocalData()
        
        // Clear all UserDefaults
        clearAllUserDefaults()
        
        // Force setup
        needsSetup = true
        syncStatus = "Reset complete - setup required"
        isSyncing = false
        
        print("✅ Complete reset performed")
    }
    
    private func clearAllUserDefaults() {
        let keys = [
            "UserProfile",
            "IsProfileSetup",
            "SavedAlbums",
            "CloudSyncEnabled",
            "LastSyncDate"
        ]
        
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // Clear all SharedAlbumData entries
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        for key in allKeys {
            if key.hasPrefix("SharedAlbumData_") {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
    
    // MARK: - Debug and Testing Methods
    
    func skipValidationForTesting() {
        print("⚠️ SKIPPING VALIDATION FOR TESTING")
        needsSetup = false
        syncComplete = true
        isSyncing = false
        syncStatus = "Validation skipped (testing mode)"
    }
    
    func forceRecreateCloudUser() async {
        guard let profile = userManager.userProfile else {
            print("❌ No local profile to recreate")
            return
        }
        
        print("🔄 Force recreating cloud user...")
        syncStatus = "Recreating user..."
        isSyncing = true
        
        let success = await attemptUserRecreation(profile)
        
        if success {
            syncComplete = true
            syncStatus = "User recreated successfully"
        } else {
            needsSetup = true
            syncStatus = "Recreation failed - setup required"
        }
        
        isSyncing = false
    }
    
    // MARK: - Status Helpers
    
    var isValidatingUser: Bool {
        return isSyncing && syncStatus.contains("user")
    }
    
    var isSyncingAlbums: Bool {
        return isSyncing && syncStatus.contains("album")
    }
    
    var shouldShowSetup: Bool {
        return needsSetup || (!syncComplete && !userManager.isProfileSetup)
    }
}

// MARK: - DataPersistenceManager Extensions

extension DataPersistenceManager {
    
    func clearAllLocalData() {
        print("🗑️ Clearing all local albums")
        
        savedAlbums.removeAll()
        saveAlbumsMetadata()
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "SavedAlbums")
    }
    
    func deleteAlbumLocally(_ album: Album) {
        if let index = savedAlbums.firstIndex(where: { $0.id == album.id }) {
            savedAlbums.remove(at: index)
            saveAlbumsMetadata()
            print("🗑️ Removed local album: \(album.title)")
        }
    }
    
    func updateAlbumLocally(_ album: Album) {
        if let index = savedAlbums.firstIndex(where: { $0.id == album.id }) {
            savedAlbums[index] = album
            saveAlbumsMetadata()
            print("🔄 Updated local album: \(album.title)")
        }
    }
    
    func addAlbumLocally(_ album: Album) {
        if !savedAlbums.contains(where: { $0.id == album.id }) {
            savedAlbums.append(album)
            savedAlbums.sort { $0.releaseDate > $1.releaseDate }
            saveAlbumsMetadata()
            print("⬇️ Added album locally: \(album.title)")
        }
    }
}
