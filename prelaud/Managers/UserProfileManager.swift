//
//  UserProfileManager.swift - ENHANCED WITH PROPER DATABASE SYNC
//  prelaud
//
//  Fixed database synchronization for all profile updates
//

import Foundation
import UIKit
import SwiftUI

@MainActor
class UserProfileManager: ObservableObject {
    static let shared = UserProfileManager()
    
    @Published var isProfileSetup: Bool = false
    @Published var userProfile: UserProfile?
    @Published var isCheckingUsername: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let profileKey = "UserProfile"
    private let setupCompleteKey = "ProfileSetupComplete"
    
    // Database manager for username operations
    private let databaseManager = UsernameDatabaseManager.shared
    
    // Reserved usernames (always blocked regardless of database)
    private let reservedUsernames: Set<String> = [
        "admin", "root", "api", "www", "mail", "ftp", "prelaud", "support",
        "help", "info", "contact", "about", "privacy", "terms", "legal",
        "music", "spotify", "apple", "amazon", "youtube", "official"
    ]
    
    private init() {
        loadProfile()
    }
    
    // MARK: - Profile Management
    
    func createProfile(username: String, artistName: String, bio: String? = nil, profileImage: UIImage? = nil) {
        print("🔄 DEBUG: createProfile called with:")
        print("   - username: \(username)")
        print("   - artistName: \(artistName)")
        print("   - bio: \(bio ?? "nil")")
        
        let profile = UserProfile(
            id: UUID(),
            username: username,
            artistName: artistName,
            bio: bio,
            profileImage: profileImage,
            createdAt: Date()
        )
        
        userProfile = profile
        isProfileSetup = true
        
        saveProfile()
        
        // Register username in database with full profile data
        Task {
            do {
                print("🚀 DEBUG: About to register user in database")
                try await databaseManager.registerUsername(
                    username,
                    userId: profile.id.uuidString,
                    artistName: artistName,
                    bio: bio
                )
                print("✅ User registered in database: @\(username) - \(artistName)")
            } catch {
                print("❌ Failed to register user in database: \(error)")
                // Note: Profile creation still succeeds even if database registration fails
            }
        }
        
        print("✅ Profile created: @\(username) - \(artistName)")
    }
    
    func updateProfile(username: String? = nil, artistName: String? = nil, bio: String? = nil, profileImage: UIImage? = nil) {
        guard var profile = userProfile else {
            print("❌ No profile to update")
            return
        }
        
        print("🔄 DEBUG: updateProfile called with:")
        print("   - username: \(username ?? "nil")")
        print("   - artistName: \(artistName ?? "nil")")
        print("   - bio: \(bio ?? "nil")")
        print("   - current profile ID: \(profile.id.uuidString)")
        print("   - current username: \(profile.username)")
        print("   - current artistName: \(profile.artistName)")
        
        let oldUsername = profile.username
        let oldArtistName = profile.artistName
        let oldBio = profile.bio
        
        // Update locally first
        if let username = username { profile.username = username }
        if let artistName = artistName { profile.artistName = artistName }
        if let bio = bio { profile.bio = bio }
        if let profileImage = profileImage { profile.profileImage = profileImage }
        
        profile.updatedAt = Date()
        userProfile = profile
        
        saveProfile()
        
        // 🚀 NEW: Comprehensive database sync
        Task {
            do {
                print("🚀 DEBUG: Starting database sync...")
                
                // Check what actually changed
                let usernameChanged = username != nil && username != oldUsername
                let artistNameChanged = artistName != nil && artistName != oldArtistName
                let bioChanged = bio != oldBio
                
                print("🔍 DEBUG: Changes detected:")
                print("   - Username changed: \(usernameChanged)")
                print("   - Artist name changed: \(artistNameChanged)")
                print("   - Bio changed: \(bioChanged)")
                
                if usernameChanged || artistNameChanged || bioChanged {
                    print("🚀 DEBUG: Calling updateUser with:")
                    print("   - userId: \(profile.id.uuidString)")
                    print("   - username: \(username ?? "nil")")
                    print("   - artistName: \(artistName ?? "nil")")
                    print("   - bio: \(bio ?? "nil")")
                    
                    try await databaseManager.updateUser(
                        userId: profile.id.uuidString,
                        username: username,
                        artistName: artistName,
                        bio: bio
                    )
                    print("✅ Profile completely updated in database")
                } else {
                    print("🔍 No relevant changes for database update")
                }
                
            } catch {
                print("❌ Failed to update profile in database: \(error)")
                
                // Optional: Revert local changes on database failure
                // This depends on your UX requirements
                print("⚠️ Database update failed, but local changes remain")
            }
        }
        
        print("✅ Profile updated locally: @\(profile.username) - \(profile.artistName)")
    }
    
    func deleteProfile() {
        guard let profile = userProfile else { return }
        let oldUsername = profile.username
        let userId = profile.id.uuidString
        
        userProfile = nil
        isProfileSetup = false
        
        userDefaults.removeObject(forKey: profileKey)
        userDefaults.set(false, forKey: setupCompleteKey)
        
        // Delete profile image
        deleteProfileImage()
        
        // Release username in database
        Task {
            do {
                try await databaseManager.releaseUsername(oldUsername, userId: userId)
                print("✅ Username released in database: \(oldUsername)")
            } catch {
                print("❌ Failed to release username in database: \(error)")
            }
        }
        
        print("🗑️ Profile deleted")
    }
    
    // MARK: - Username Availability Check
    
    func checkUsernameAvailability(_ username: String) async -> UsernameCheckResult {
        print("🔍 Checking username availability: \(username)")
        
        // Set loading state
        isCheckingUsername = true
        defer { isCheckingUsername = false }
        
        // First do local validation
        let localValidation = isUsernameValid(username)
        if !localValidation.isValid {
            return .invalid(localValidation.error ?? "Invalid username")
        }
        
        // Check reserved usernames locally
        let normalizedUsername = username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if reservedUsernames.contains(normalizedUsername) {
            return .taken("This username is reserved")
        }
        
        // STRICT database check - no fallback
        do {
            let isAvailable = try await databaseManager.checkUsernameAvailability(username)
            
            if isAvailable {
                return .available
            } else {
                return .taken("Username is already taken")
            }
        } catch DatabaseError.checkFailed {
            print("💥 Database check failed - cannot verify username")
            return .serverError("Cannot connect to server. Please check your internet connection and try again.")
        } catch {
            print("❌ Database check error: \(error)")
            return .serverError("Unable to verify username availability. Please try again.")
        }
    }
    
    // MARK: - Enhanced Username Validation
    
    func isUsernameValid(_ username: String) -> (isValid: Bool, error: String?) {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Empty check
        guard !trimmed.isEmpty else {
            return (false, "Username cannot be empty")
        }
        
        // Length check
        guard trimmed.count >= 3 else {
            return (false, "Username must be at least 3 characters")
        }
        
        guard trimmed.count <= 20 else {
            return (false, "Username must be 20 characters or less")
        }
        
        // Character check - only alphanumeric, underscore, dash, dot
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_.-"))
        guard trimmed.rangeOfCharacter(from: allowedCharacters.inverted) == nil else {
            return (false, "Username can only contain letters, numbers, _, -, and .")
        }
        
        // Must start with letter or number
        guard let firstChar = trimmed.first, firstChar.isLetter || firstChar.isNumber else {
            return (false, "Username must start with a letter or number")
        }
        
        // Must end with letter or number
        guard let lastChar = trimmed.last, lastChar.isLetter || lastChar.isNumber else {
            return (false, "Username must end with a letter or number")
        }
        
        // Cannot have consecutive special characters
        let specialChars = CharacterSet(charactersIn: "_.-")
        var previousWasSpecial = false
        
        for char in trimmed {
            let isSpecial = specialChars.contains(char.unicodeScalars.first!)
            if isSpecial && previousWasSpecial {
                return (false, "Username cannot have consecutive special characters")
            }
            previousWasSpecial = isSpecial
        }
        
        // Reserved words check
        let reserved = ["admin", "root", "api", "www", "mail", "ftp", "prelaud", "support"]
        if reserved.contains(trimmed.lowercased()) {
            return (false, "This username is reserved")
        }
        
        return (true, nil)
    }
    
    // MARK: - Artist Name Validation (Enhanced)
    
    func isArtistNameValid(_ artistName: String) -> (isValid: Bool, error: String?) {
        let trimmed = artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return (false, "Artist name cannot be empty")
        }
        
        guard trimmed.count >= 2 else {
            return (false, "Artist name must be at least 2 characters")
        }
        
        guard trimmed.count <= 50 else {
            return (false, "Artist name must be 50 characters or less")
        }
        
        // Allow letters, numbers, spaces, and common punctuation
        let allowedCharacters = CharacterSet.alphanumerics
            .union(CharacterSet.whitespaces)
            .union(CharacterSet(charactersIn: ".-'&"))
        
        guard trimmed.rangeOfCharacter(from: allowedCharacters.inverted) == nil else {
            return (false, "Artist name contains invalid characters")
        }
        
        return (true, nil)
    }
    
    // MARK: - Computed Properties
    
    var displayName: String {
        userProfile?.artistName ?? "Your Music"
    }
    
    var username: String {
        userProfile?.username ?? ""
    }
    
    var profileImageURL: URL? {
        guard let profile = userProfile else { return nil }
        return getProfileImageURL(for: profile.id)
    }
    
    // MARK: - Persistence
    
    private func saveProfile() {
        guard let profile = userProfile else { return }
        
        // Save profile data
        let profileData = ProfileData(
            id: profile.id,
            username: profile.username,
            artistName: profile.artistName,
            bio: profile.bio,
            createdAt: profile.createdAt,
            updatedAt: profile.updatedAt
        )
        
        if let encoded = try? JSONEncoder().encode(profileData) {
            userDefaults.set(encoded, forKey: profileKey)
            userDefaults.set(true, forKey: setupCompleteKey)
        }
        
        // Save profile image separately
        saveProfileImage(profile.profileImage, for: profile.id)
    }
    
    private func loadProfile() {
        // Check if setup is complete
        isProfileSetup = userDefaults.bool(forKey: setupCompleteKey)
        
        guard isProfileSetup,
              let data = userDefaults.data(forKey: profileKey),
              let profileData = try? JSONDecoder().decode(ProfileData.self, from: data) else {
            return
        }
        
        // Load profile image
        let profileImage = loadProfileImage(for: profileData.id)
        
        userProfile = UserProfile(
            id: profileData.id,
            username: profileData.username,
            artistName: profileData.artistName,
            bio: profileData.bio,
            profileImage: profileImage,
            createdAt: profileData.createdAt,
            updatedAt: profileData.updatedAt
        )
        
        print("📂 Profile loaded: @\(profileData.username) - \(profileData.artistName)")
    }
    
    // MARK: - Image Management
    
    private func saveProfileImage(_ image: UIImage?, for profileId: UUID) {
        guard let image = image else { return }
        
        let imageURL = getProfileImageURL(for: profileId)
        
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            try? imageData.write(to: imageURL)
            print("🖼️ Profile image saved")
        }
    }
    
    private func loadProfileImage(for profileId: UUID) -> UIImage? {
        let imageURL = getProfileImageURL(for: profileId)
        return UIImage(contentsOfFile: imageURL.path)
    }
    
    private func deleteProfileImage() {
        guard let profile = userProfile else { return }
        let imageURL = getProfileImageURL(for: profile.id)
        try? FileManager.default.removeItem(at: imageURL)
    }
    
    private func getProfileImageURL(for profileId: UUID) -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("profile_\(profileId.uuidString).jpg")
    }
    
    // MARK: - Social Features
    
    func generateShareableProfile() -> String {
        guard let profile = userProfile else { return "" }
        return "Check out @\(profile.username) on prelaud - \(profile.artistName)"
    }
    
    func getProfileStats() -> ProfileStats {
        // This would integrate with DataPersistenceManager
        let albumCount = DataPersistenceManager.shared.savedAlbums.count
        let songCount = DataPersistenceManager.shared.savedAlbums.reduce(0) { $0 + $1.songs.count }
        
        return ProfileStats(
            albumCount: albumCount,
            songCount: songCount,
            memberSince: userProfile?.createdAt ?? Date()
        )
    }
    
    // MARK: - Debug Functions
    
    func debugDatabaseUser() async {
        guard let profile = userProfile else {
            print("❌ No profile to debug")
            return
        }
        
        print("🔍 DEBUG: Fetching user from database...")
        
        do {
            let dbUser = try await databaseManager.getUser(byId: profile.id.uuidString)
            print("✅ Database user found:")
            print("   - ID: \(dbUser.id)")
            print("   - Username: \(dbUser.username)")
            print("   - Artist Name: \(dbUser.artistName)")
            print("   - Bio: \(dbUser.bio ?? "nil")")
            print("   - Created: \(dbUser.createdAt)")
            print("   - Updated: \(dbUser.updatedAt)")
            print("   - Active: \(dbUser.isActive)")
        } catch {
            print("❌ Failed to fetch user from database: \(error)")
        }
    }
    
    func forceProfileSync() async {
        guard let profile = userProfile else {
            print("❌ No profile to sync")
            return
        }
        
        print("🔄 Force syncing profile to database...")
        
        do {
            try await databaseManager.updateUser(
                userId: profile.id.uuidString,
                username: profile.username,
                artistName: profile.artistName,
                bio: profile.bio
            )
            print("✅ Profile force-synced to database")
        } catch {
            print("❌ Failed to force-sync profile: \(error)")
        }
    }
    
    // MARK: - 🚧 DEBUG FUNCTIONS (Development Only)
    
    #if DEBUG
    /// Versteckte Debug-Funktion: Simuliert erstmalige Einrichtung
    /// Aufruf: 5x schnell auf "prelaud" Logo tippen
    func resetProfileForFirstTimeSetup() {
        print("🚧 DEBUG: Resetting profile for first-time setup simulation")
        
        // Profile komplett zurücksetzen
        userProfile = nil
        isProfileSetup = false
        
        // UserDefaults löschen
        userDefaults.removeObject(forKey: profileKey)
        userDefaults.set(false, forKey: setupCompleteKey)
        
        // Profilbild löschen
        deleteProfileImage()
        
        print("✅ DEBUG: Profile reset complete - next app start will show setup")
    }
    
    /// Debug-Funktion: Erstellt ein Test-Profil
    func createDebugProfile() {
        print("🚧 DEBUG: Creating test profile")
        
        createProfile(
            username: "testuser",
            artistName: "Debug Artist",
            bio: "This is a test profile for development",
            profileImage: nil
        )
        
        print("✅ DEBUG: Test profile created")
    }
    
    /// Debug-Funktion: Zeigt aktuellen Profile-Status
    func debugProfileStatus() {
        print("🚧 DEBUG: Profile Status")
        print("   - isProfileSetup: \(isProfileSetup)")
        print("   - userProfile exists: \(userProfile != nil)")
        if let profile = userProfile {
            print("   - username: @\(profile.username)")
            print("   - artistName: \(profile.artistName)")
            print("   - created: \(profile.createdAt)")
            print("   - bio: \(profile.bio ?? "nil")")
        }
        
        Task {
            await debugDatabaseUser()
        }
    }
    #endif
}

// MARK: - Username Check Result

enum UsernameCheckResult: Equatable {
    case available
    case taken(String)
    case invalid(String)
    case serverError(String)
    
    var isValid: Bool {
        switch self {
        case .available:
            return true
        default:
            return false
        }
    }
    
    var errorMessage: String? {
        switch self {
        case .available:
            return nil
        case .taken(let message),
             .invalid(let message),
             .serverError(let message):
            return message
        }
    }
    
    // Equatable conformance
    static func == (lhs: UsernameCheckResult, rhs: UsernameCheckResult) -> Bool {
        switch (lhs, rhs) {
        case (.available, .available):
            return true
        case (.taken(let lhsMessage), .taken(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.invalid(let lhsMessage), .invalid(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.serverError(let lhsMessage), .serverError(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

// MARK: - Data Models

struct UserProfile {
    let id: UUID
    var username: String
    var artistName: String
    var bio: String?
    var profileImage: UIImage?
    let createdAt: Date
    var updatedAt: Date?
}

struct ProfileData: Codable {
    let id: UUID
    let username: String
    let artistName: String
    let bio: String?
    let createdAt: Date
    let updatedAt: Date?
}

struct ProfileStats {
    let albumCount: Int
    let songCount: Int
    let memberSince: Date
    
    var memberSinceFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: memberSince)
    }
}
