//
//  UserProfileManager.swift - FIXED USER VALIDATION
//  prelaud
//
//  Complete fix for user validation and cloudId management
//

import Foundation
import SwiftUI

@MainActor
class UserProfileManager: ObservableObject {
    static let shared = UserProfileManager()
    
    @Published var userProfile: UserProfile?
    @Published var isProfileSetup = false
    @Published var isCreatingProfile = false
    @Published var setupError: String?
    @Published var isCheckingUsername = false
    
    private let userDefaults = UserDefaults.standard
    private let profileKey = "UserProfile"
    private let setupCompleteKey = "IsProfileSetup"
    private let pocketBase = PocketBaseManager.shared
    
    private init() {
        loadProfile()
        migrateFromSupabase()
    }
    
    // MARK: - Profile Creation (FIXED WITH PROPER CLOUD ID HANDLING)
    
    func createProfile(username: String, artistName: String, bio: String? = nil, profileImage: UIImage? = nil) {
        guard !isCreatingProfile else { return }
        
        isCreatingProfile = true
        setupError = nil
        
        Task {
            do {
                // 1. Test connection first
                let isConnected = await pocketBase.performHealthCheck()
                guard isConnected else {
                    await MainActor.run {
                        setupError = "No internet connection. Please check your connection and try again."
                        isCreatingProfile = false
                    }
                    return
                }
                
                // 2. Create user in PocketBase first
                let cloudUser = try await createPocketBaseUser(
                    username: username,
                    artistName: artistName,
                    bio: bio
                )
                
                print("✅ PocketBase user created: \(cloudUser.id)")
                
                // 3. Create local profile with cloudId
                let profile = UserProfile(
                    id: UUID(),
                    username: username.lowercased(),
                    artistName: artistName,
                    bio: bio,
                    profileImage: profileImage,
                    createdAt: Date(),
                    cloudId: cloudUser.id // ← CRITICAL: Set cloudId here
                )
                
                await MainActor.run {
                    userProfile = profile
                    isProfileSetup = true
                    isCreatingProfile = false
                    setupError = nil
                    
                    saveProfile()
                    
                    print("✅ Profile created successfully: @\(username) with cloudId: \(cloudUser.id)")
                }
                
            } catch {
                await MainActor.run {
                    isCreatingProfile = false
                    
                    if let profileError = error as? ProfileError {
                        switch profileError {
                        case .usernameError:
                            setupError = "Username already taken. Please choose another."
                        case .validationError:
                            setupError = "Invalid profile data. Please check your input."
                        case .permissionDenied:
                            setupError = "Setup not allowed. Please contact support."
                        case .collectionNotFound:
                            setupError = "Database not configured. Please contact support."
                        case .networkError:
                            setupError = "Network connection failed. Check your internet."
                        default:
                            setupError = "Profile creation failed. Please try again."
                        }
                    } else {
                        setupError = "Profile creation failed. Please check your connection."
                    }
                    
                    print("❌ Setup failed with error: \(setupError ?? "unknown")")
                }
            }
        }
    }
    
    // MARK: - PocketBase User Creation (FIXED)
    
    private func createPocketBaseUser(username: String, artistName: String, bio: String?) async throws -> PBUser {
        print("🔗 Creating PocketBase user...")
        
        let userData: [String: Any] = [
            "username": username.lowercased(),
            "artist_name": artistName,
            "bio": bio ?? "",
            "is_active": true,
            "created": ISO8601DateFormatter().string(from: Date())
        ]
        
        let url = URL(string: "\(pocketBase.baseURL)/api/collections/users/records")!
        var request = pocketBase.createRequest(url: url, method: "POST")
        request.httpBody = try JSONSerialization.data(withJSONObject: userData)
        
        let (data, response) = try await pocketBase.urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProfileError.networkError
        }
        
        print("📋 PocketBase user creation status: \(httpResponse.statusCode)")
        
        switch httpResponse.statusCode {
        case 200:
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let userId = json["id"] as? String,
               let username = json["username"] as? String {
                
                let user = PBUser(
                    id: userId,
                    username: username,
                    artistName: json["artist_name"] as? String ?? artistName,
                    bio: json["bio"] as? String ?? "",
                    isActive: true,
                    created: json["created"] as? String ?? "",
                    updated: json["updated"] as? String ?? ""
                )
                
                print("✅ PocketBase user created successfully: \(userId)")
                return user
            } else {
                print("❌ Failed to parse user creation response")
                throw ProfileError.parsingError
            }
            
        case 400:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            if errorMessage.contains("username") {
                print("❌ Username validation error: \(errorMessage)")
                throw ProfileError.usernameError
            } else {
                print("❌ Validation error: \(errorMessage)")
                throw ProfileError.validationError
            }
            
        case 403:
            print("❌ 403 Forbidden - User creation not allowed")
            throw ProfileError.permissionDenied
            
        case 404:
            print("❌ 404 Not Found - users collection doesn't exist")
            throw ProfileError.collectionNotFound
            
        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ User creation failed: \(httpResponse.statusCode) - \(errorMessage)")
            throw ProfileError.creationFailed
        }
    }
    
    // MARK: - Profile Management
    
    func saveProfile() {
        guard let profile = userProfile else { return }
        
        let profileData = ProfileData(
            id: profile.id,
            username: profile.username,
            artistName: profile.artistName,
            bio: profile.bio,
            createdAt: profile.createdAt,
            updatedAt: Date(),
            cloudId: profile.cloudId // ← Save cloudId too
        )
        
        if let encoded = try? JSONEncoder().encode(profileData) {
            userDefaults.set(encoded, forKey: profileKey)
            userDefaults.set(true, forKey: setupCompleteKey)
        }
        
        saveProfileImage(profile.profileImage, for: profile.id)
        print("💾 Profile saved with cloudId: \(profile.cloudId ?? "none")")
    }
    
    private func loadProfile() {
        isProfileSetup = userDefaults.bool(forKey: setupCompleteKey)
        
        guard isProfileSetup,
              let data = userDefaults.data(forKey: profileKey),
              let profileData = try? JSONDecoder().decode(ProfileData.self, from: data) else {
            print("📂 No profile found or setup incomplete")
            return
        }
        
        let profileImage = loadProfileImage(for: profileData.id)
        
        userProfile = UserProfile(
            id: profileData.id,
            username: profileData.username,
            artistName: profileData.artistName,
            bio: profileData.bio,
            profileImage: profileImage,
            createdAt: profileData.createdAt,
            updatedAt: profileData.updatedAt,
            cloudId: profileData.cloudId // ← Load cloudId too
        )
        
        print("📂 Profile loaded: @\(profileData.username) with cloudId: \(profileData.cloudId ?? "MISSING")")
        
        // Check if cloudId is missing and fix it
        if userProfile?.cloudId == nil {
            print("⚠️ Profile missing cloudId - will need to recreate")
        }
    }
    
    func deleteProfile() {
        guard userProfile != nil else { return }
        
        userProfile = nil
        isProfileSetup = false
        
        userDefaults.removeObject(forKey: profileKey)
        userDefaults.set(false, forKey: setupCompleteKey)
        
        deleteProfileImage()
        
        print("🗑️ Profile deleted")
    }
    
    // MARK: - Profile Image Management
    
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
        return documentsDirectory.appendingPathComponent("profile_image_\(profileId.uuidString).jpg")
    }
    
    // MARK: - Username Validation
    
    func checkUsernameAvailability(_ username: String) async -> UsernameCheckResult {
        print("🔍 Checking username availability: \(username)")
        
        isCheckingUsername = true
        defer { isCheckingUsername = false }
        
        // Local validation first
        let localValidation = isUsernameValid(username)
        if !localValidation.isValid {
            return .invalid(localValidation.error ?? "Invalid username")
        }
        
        // Database check
        do {
            let result = try await pocketBase.checkUsernameAvailability(username)
            return result.isValid ? .available : .taken(result.errorMessage ?? "Username taken")
        } catch {
            print("❌ Username check error: \(error)")
            return .serverError("Unable to verify username availability")
        }
    }
    
    private func isUsernameValid(_ username: String) -> (isValid: Bool, error: String?) {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return (false, "Username cannot be empty")
        }
        
        guard trimmed.count >= 3 else {
            return (false, "Username must be at least 3 characters")
        }
        
        guard trimmed.count <= 20 else {
            return (false, "Username must be 20 characters or less")
        }
        
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_.-"))
        guard trimmed.rangeOfCharacter(from: allowedCharacters.inverted) == nil else {
            return (false, "Username can only contain letters, numbers, _, -, and .")
        }
        
        guard let firstChar = trimmed.first, firstChar.isLetter || firstChar.isNumber else {
            return (false, "Username must start with a letter or number")
        }
        
        guard let lastChar = trimmed.last, lastChar.isLetter || lastChar.isNumber else {
            return (false, "Username must end with a letter or number")
        }
        
        return (true, nil)
    }
    
    // MARK: - Migration and Cleanup
    
    private func migrateFromSupabase() {
        if UserDefaults.standard.data(forKey: "CloudUser") != nil {
            UserDefaults.standard.removeObject(forKey: "CloudUser")
            print("🔄 Cleaned up old Supabase user data")
        }
    }
    
    // MARK: - Fix Missing CloudId
    
    func fixMissingCloudId() async -> Bool {
        guard let profile = userProfile, profile.cloudId == nil else {
            return true // Already has cloudId
        }
        
        print("🔧 Attempting to fix missing cloudId for @\(profile.username)")
        
        do {
            // Try to find existing user by username
            if let existingUser = try? await pocketBase.getUserByUsername(profile.username) {
                print("✅ Found existing user in database")
                
                // Update local profile with cloudId
                var updatedProfile = profile
                updatedProfile.cloudId = existingUser.id
                userProfile = updatedProfile
                saveProfile()
                
                return true
            } else {
                // Create new user in database
                let cloudUser = try await createPocketBaseUser(
                    username: profile.username,
                    artistName: profile.artistName,
                    bio: profile.bio
                )
                
                // Update local profile with cloudId
                var updatedProfile = profile
                updatedProfile.cloudId = cloudUser.id
                userProfile = updatedProfile
                saveProfile()
                
                print("✅ Created new user and fixed cloudId")
                return true
            }
        } catch {
            print("❌ Failed to fix missing cloudId: \(error)")
            return false
        }
    }
    
    // MARK: - Artist Name Validation
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
        
        // Allow letters, numbers, spaces, and some special characters
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -'&."))
        guard trimmed.rangeOfCharacter(from: allowedCharacters.inverted) == nil else {
            return (false, "Artist name contains invalid characters")
        }
        
        return (true, nil)
    }
    
    // MARK: - Profile Update
    func updateProfile(username: String? = nil, artistName: String? = nil, bio: String? = nil, profileImage: UIImage? = nil) {
        guard var profile = userProfile else { return }
        
        // Update fields if provided
        if let username = username, !username.isEmpty {
            profile.username = username
        }
        
        if let artistName = artistName, !artistName.isEmpty {
            profile.artistName = artistName
        }
        
        if let bio = bio {
            profile.bio = bio.isEmpty ? nil : bio
        }
        
        if let profileImage = profileImage {
            profile.profileImage = profileImage
        }
        
        // Update timestamp
        profile.updatedAt = Date()
        
        // Update the published property
        userProfile = profile
        
        // Save changes
        saveProfile()
        
        print("✅ Profile updated: @\(profile.username)")
    }
    
    // MARK: - Debug Functions
    
    #if DEBUG
    func resetProfileForFirstTimeSetup() {
        print("🚧 DEBUG: Resetting profile")
        deleteProfile()
    }
    
    func createDebugProfile() {
        print("🚧 DEBUG: Creating test profile")
        createProfile(
            username: "testuser\(Int.random(in: 1000...9999))",
            artistName: "Debug Artist",
            bio: "This is a debug profile created for testing."
        )
    }
    
    func debugProfileStatus() {
        print("🚧 DEBUG: Profile Status")
        print("  - isProfileSetup: \(isProfileSetup)")
        print("  - username: \(userProfile?.username ?? "none")")
        print("  - artistName: \(userProfile?.artistName ?? "none")")
        print("  - cloudId: \(userProfile?.cloudId ?? "❌ MISSING")")
        print("  - setupError: \(setupError ?? "none")")
    }
    #endif
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
    var cloudId: String? // ← PocketBase user ID - CRITICAL for validation
    
    init(id: UUID, username: String, artistName: String, bio: String? = nil, profileImage: UIImage? = nil, createdAt: Date, updatedAt: Date? = nil, cloudId: String? = nil) {
        self.id = id
        self.username = username
        self.artistName = artistName
        self.bio = bio
        self.profileImage = profileImage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.cloudId = cloudId
    }
}

struct ProfileData: Codable {
    let id: UUID
    let username: String
    let artistName: String
    let bio: String?
    let createdAt: Date
    let updatedAt: Date?
    let cloudId: String? // ← Include cloudId in serialization
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
}

// MARK: - Error Types

enum ProfileError: Error, LocalizedError {
    case networkError
    case usernameError
    case validationError
    case permissionDenied
    case collectionNotFound
    case creationFailed
    case parsingError
    case checkFailed
    
    var errorDescription: String? {
        switch self {
        case .networkError: return "Network connection failed"
        case .usernameError: return "Username validation failed"
        case .validationError: return "Input validation failed"
        case .permissionDenied: return "Permission denied"
        case .collectionNotFound: return "Collection not found"
        case .creationFailed: return "Failed to create user"
        case .parsingError: return "Failed to parse response"
        case .checkFailed: return "Username check failed"
        }
    }
}


