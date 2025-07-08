//
//  SupabaseUserManager.swift
//  MusicPreview
//
//  Cloud-based user management with unique usernames - FIXED VERSION
//

import Foundation
import UIKit
import SwiftUI

@MainActor
class SupabaseUserManager: ObservableObject {
    static let shared = SupabaseUserManager()
    
    @Published var isProfileSetup: Bool = false
    @Published var currentUser: CloudUser?
    @Published var isConnected: Bool = false
    @Published var connectionError: String?
    
    // Username checking
    @Published var isCheckingUsername: Bool = false
    @Published var usernameAvailable: Bool? = nil
    @Published var lastCheckedUsername: String = ""
    
    // Supabase Configuration
    private let supabaseURL = "https://auzsunnwanzljiwdpzov.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1enN1bm53YW56bGppd2Rwem92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIxMzIyNjksImV4cCI6MjA2NzcwODI2OX0.UmuoVT-7uXq5SMFr9duiurbE52Oe865w4ghYPkFwexE"
    
    private var urlSession: URLSession
    private let deviceId: String
    
    // Local UserProfileManager for migration
    private let localProfileManager = UserProfileManager.shared
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 30.0
        urlSession = URLSession(configuration: config)
        
        // Generate unique device identifier
        if let savedDeviceId = UserDefaults.standard.string(forKey: "DeviceIdentifier") {
            deviceId = savedDeviceId
        } else {
            deviceId = UUID().uuidString
            UserDefaults.standard.set(deviceId, forKey: "DeviceIdentifier")
        }
        
        loadLocalUser()
        checkConnection()
    }
    
    // MARK: - Request Helper (FIXED)
    
    private func createRequest(url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // CRITICAL: Both headers are required for Supabase
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        return request
    }
    
    // MARK: - Connection Management
    
    func checkConnection() {
        Task {
            do {
                let isConnected = try await testConnection()
                await MainActor.run {
                    self.isConnected = isConnected
                    self.connectionError = nil
                    
                    if isConnected {
                        print("✅ Supabase connected successfully")
                        migrateLocalProfileIfNeeded()
                    } else {
                        print("❌ Supabase connection failed")
                    }
                }
            } catch {
                await MainActor.run {
                    self.isConnected = false
                    self.connectionError = error.localizedDescription
                    print("❌ Supabase connection error: \(error)")
                }
            }
        }
    }
    
    private func testConnection() async throws -> Bool {
        let url = URL(string: "\(supabaseURL)/rest/v1/users?select=count&limit=1")!
        let request = createRequest(url: url)
        
        let (_, response) = try await urlSession.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            let success = (200...299).contains(httpResponse.statusCode)
            print("🔗 Connection test - Status: \(httpResponse.statusCode), Success: \(success)")
            return success
        }
        
        return false
    }
    
    // MARK: - Username Management
    
    func checkUsernameAvailability(_ username: String) {
        // Cancel previous check
        guard !username.isEmpty else {
            usernameAvailable = nil
            lastCheckedUsername = ""
            return
        }
        
        // Basic validation first
        let validation = validateUsernameFormat(username)
        guard validation.isValid else {
            usernameAvailable = false
            lastCheckedUsername = username
            return
        }
        
        // Don't check same username twice
        guard username != lastCheckedUsername else { return }
        
        lastCheckedUsername = username
        isCheckingUsername = true
        usernameAvailable = nil
        
        Task {
            do {
                let available = try await isUsernameAvailable(username)
                
                await MainActor.run {
                    // Only update if this is still the current username being checked
                    if username == self.lastCheckedUsername {
                        self.usernameAvailable = available
                        self.isCheckingUsername = false
                        print("✅ Username '\(username)' available: \(available)")
                    }
                }
            } catch {
                await MainActor.run {
                    if username == self.lastCheckedUsername {
                        self.usernameAvailable = false
                        self.isCheckingUsername = false
                        print("❌ Username check failed: \(error)")
                    }
                }
            }
        }
    }
    
    private func isUsernameAvailable(_ username: String) async throws -> Bool {
        let url = URL(string: "\(supabaseURL)/rest/v1/rpc/is_username_available")!
        var request = createRequest(url: url, method: "POST")
        
        let body = ["check_username": username]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await urlSession.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("🔍 Username check response: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                if let result = try? JSONSerialization.jsonObject(with: data) as? Bool {
                    return result
                }
            }
            
            // If function doesn't exist, fallback to direct table check
            if httpResponse.statusCode == 404 {
                return try await checkUsernameDirectly(username)
            }
        }
        
        throw SupabaseUserError.usernameCheckFailed
    }
    
    // Fallback method if RPC function doesn't exist
    private func checkUsernameDirectly(_ username: String) async throws -> Bool {
        let encodedUsername = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username
        let url = URL(string: "\(supabaseURL)/rest/v1/users?select=username&username=ilike.\(encodedUsername)")!
        let request = createRequest(url: url)
        
        let (data, response) = try await urlSession.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            if let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                return results.isEmpty // Available if no results found
            }
        }
        
        throw SupabaseUserError.usernameCheckFailed
    }
    
    func reserveUsername(_ username: String) async throws -> Bool {
        let url = URL(string: "\(supabaseURL)/rest/v1/rpc/reserve_username")!
        var request = createRequest(url: url, method: "POST")
        
        let body = [
            "reserve_username": username,
            "device_identifier": deviceId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await urlSession.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("🔒 Username reservation response: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                if let result = try? JSONSerialization.jsonObject(with: data) as? Bool {
                    return result
                }
            }
            
            // If function doesn't exist, skip reservation (just proceed)
            if httpResponse.statusCode == 404 {
                print("⚠️ Username reservation function not available, proceeding without reservation")
                return true
            }
        }
        
        throw SupabaseUserError.usernameReservationFailed
    }
    
    // MARK: - User Registration & Management
    
    func createUser(username: String, artistName: String, bio: String? = nil, profileImage: UIImage? = nil) async throws -> CloudUser {
        print("🆕 Creating user: @\(username)")
        
        // Try to reserve username (optional)
        do {
            let reserved = try await reserveUsername(username)
            if !reserved {
                throw SupabaseUserError.usernameNotAvailable
            }
        } catch {
            print("⚠️ Username reservation failed, checking availability directly")
            let available = try await isUsernameAvailable(username)
            if !available {
                throw SupabaseUserError.usernameNotAvailable
            }
        }
        
        // Upload profile image if provided
        var profileImageUrl: String? = nil
        if let image = profileImage {
            do {
                profileImageUrl = try await uploadProfileImage(image, userId: UUID().uuidString)
                print("📸 Profile image uploaded successfully")
            } catch {
                print("⚠️ Profile image upload failed: \(error), continuing without image")
            }
        }
        
        // Create user record
        let userId = UUID()
        let newUser = CloudUser(
            id: userId,
            username: username,
            artistName: artistName,
            bio: bio,
            profileImageUrl: profileImageUrl,
            isVerified: false,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let url = URL(string: "\(supabaseURL)/rest/v1/users")!
        var request = createRequest(url: url, method: "POST")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        let body: [String: Any] = [
            "id": userId.uuidString,
            "username": username,
            "artist_name": artistName,
            "bio": bio ?? NSNull(),
            "profile_image_url": profileImageUrl ?? NSNull()
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await urlSession.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("👤 User creation response: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 201 {
                // Save user locally
                currentUser = newUser
                isProfileSetup = true
                saveLocalUser()
                
                // Create user session
                try await createUserSession(userId: userId)
                
                print("✅ User created successfully: @\(username)")
                return newUser
            } else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ User creation failed: \(responseString)")
                }
                
                let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let errorMessage = errorData?["message"] as? String ?? "User creation failed"
                throw SupabaseUserError.userCreationFailed(errorMessage)
            }
        }
        
        throw SupabaseUserError.userCreationFailed("Invalid response")
    }
    
    func updateUser(username: String? = nil, artistName: String? = nil, bio: String? = nil, profileImage: UIImage? = nil) async throws {
        guard let user = currentUser else {
            throw SupabaseUserError.noCurrentUser
        }
        
        var updateData: [String: Any] = [:]
        
        // Check username availability if changing
        if let newUsername = username, newUsername != user.username {
            let available = try await isUsernameAvailable(newUsername)
            guard available else {
                throw SupabaseUserError.usernameNotAvailable
            }
            updateData["username"] = newUsername
        }
        
        if let artistName = artistName { updateData["artist_name"] = artistName }
        if let bio = bio { updateData["bio"] = bio }
        
        // Handle profile image
        if let image = profileImage {
            do {
                let imageUrl = try await uploadProfileImage(image, userId: user.id.uuidString)
                updateData["profile_image_url"] = imageUrl
            } catch {
                print("⚠️ Profile image update failed: \(error)")
            }
        }
        
        guard !updateData.isEmpty else { return }
        
        let url = URL(string: "\(supabaseURL)/rest/v1/users?id=eq.\(user.id.uuidString)")!
        var request = createRequest(url: url, method: "PATCH")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
        
        let (_, response) = try await urlSession.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 {
            // Update local user
            var updatedUser = user
            if let newUsername = username { updatedUser.username = newUsername }
            if let newArtistName = artistName { updatedUser.artistName = newArtistName }
            if let newBio = bio { updatedUser.bio = newBio }
            if let image = profileImage, let imageUrl = updateData["profile_image_url"] as? String {
                updatedUser.profileImageUrl = imageUrl
            }
            updatedUser.updatedAt = Date()
            
            currentUser = updatedUser
            saveLocalUser()
            
            print("✅ User updated successfully")
        } else {
            throw SupabaseUserError.userUpdateFailed
        }
    }
    
    // MARK: - Profile Image Management
    
    private func uploadProfileImage(_ image: UIImage, userId: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw SupabaseUserError.imageProcessingFailed
        }
        
        let fileName = "profile_\(userId).jpg"
        let url = URL(string: "\(supabaseURL)/storage/v1/object/profile-images/\(fileName)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("public", forHTTPHeaderField: "x-upsert")
        
        let (_, response) = try await urlSession.upload(for: request, from: imageData)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                return "\(supabaseURL)/storage/v1/object/public/profile-images/\(fileName)"
            } else {
                print("❌ Image upload failed with status: \(httpResponse.statusCode)")
            }
        }
        
        throw SupabaseUserError.imageUploadFailed
    }
    
    // MARK: - Session Management
    
    private func createUserSession(userId: UUID) async throws {
        let url = URL(string: "\(supabaseURL)/rest/v1/user_sessions")!
        var request = createRequest(url: url, method: "POST")
        
        let body: [String: Any] = [
            "user_id": userId.uuidString,
            "device_id": deviceId,
            "device_type": "ios",
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await urlSession.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if (200...299).contains(httpResponse.statusCode) {
                print("📱 User session created")
            } else {
                print("⚠️ Session creation failed with status: \(httpResponse.statusCode)")
            }
        }
    }
    
    // MARK: - Local Storage & Migration
    
    private func loadLocalUser() {
        if let data = UserDefaults.standard.data(forKey: "CloudUser"),
           let user = try? JSONDecoder().decode(CloudUser.self, from: data) {
            currentUser = user
            isProfileSetup = true
            print("📂 Loaded cloud user: @\(user.username)")
        } else {
            // Check if we have a local profile to migrate
            isProfileSetup = localProfileManager.isProfileSetup
            print("📂 No cloud user found, isProfileSetup: \(isProfileSetup)")
        }
    }
    
    private func saveLocalUser() {
        if let user = currentUser,
           let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "CloudUser")
            print("💾 Saved cloud user locally")
        }
    }
    
    private func migrateLocalProfileIfNeeded() {
        guard !isProfileSetup,
              let localProfile = localProfileManager.userProfile,
              isConnected else { return }
        
        print("🔄 Migrating local profile to cloud...")
        
        Task {
            do {
                let cloudUser = try await createUser(
                    username: localProfile.username,
                    artistName: localProfile.artistName,
                    bio: localProfile.bio,
                    profileImage: localProfile.profileImage
                )
                
                await MainActor.run {
                    print("✅ Profile migrated successfully: @\(cloudUser.username)")
                }
            } catch {
                print("❌ Profile migration failed: \(error)")
            }
        }
    }
    
    // MARK: - Validation
    
    func validateUsernameFormat(_ username: String) -> (isValid: Bool, error: String?) {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmed.count >= 3 else {
            return (false, "Username must be at least 3 characters")
        }
        
        guard trimmed.count <= 50 else {
            return (false, "Username must be 50 characters or less")
        }
        
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_.-"))
        guard trimmed.rangeOfCharacter(from: allowedCharacters.inverted) == nil else {
            return (false, "Username can only contain letters, numbers, _, -, and .")
        }
        
        guard let firstChar = trimmed.first, firstChar.isLetter || firstChar.isNumber else {
            return (false, "Username must start with a letter or number")
        }
        
        guard !trimmed.hasPrefix(".") && !trimmed.hasSuffix(".") && !trimmed.contains("..") else {
            return (false, "Invalid username format")
        }
        
        return (true, nil)
    }
    
    func validateArtistName(_ artistName: String) -> (isValid: Bool, error: String?) {
        let trimmed = artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmed.count >= 2 else {
            return (false, "Artist name must be at least 2 characters")
        }
        
        guard trimmed.count <= 100 else {
            return (false, "Artist name must be 100 characters or less")
        }
        
        return (true, nil)
    }
    
    // MARK: - Computed Properties
    
    var displayName: String {
        currentUser?.artistName ?? localProfileManager.displayName
    }
    
    var username: String {
        currentUser?.username ?? localProfileManager.username
    }
    
    // MARK: - Username Suggestions
    
    func generateUsernameSuggestions(from artistName: String) -> [String] {
        let baseUsername = artistName
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
        
        var suggestions: [String] = []
        
        // Base username
        if !baseUsername.isEmpty {
            suggestions.append(baseUsername)
        }
        
        // With numbers
        for i in 1...99 {
            suggestions.append("\(baseUsername)\(i)")
        }
        
        // With underscores
        suggestions.append("\(baseUsername)_")
        suggestions.append("_\(baseUsername)")
        
        // With common suffixes
        let suffixes = ["music", "beats", "official", "artist"]
        for suffix in suffixes {
            suggestions.append("\(baseUsername)\(suffix)")
            suggestions.append("\(baseUsername)_\(suffix)")
        }
        
        return Array(suggestions.prefix(10)) // Return first 10 suggestions
    }
}

// MARK: - Cloud User Model

struct CloudUser: Codable, Identifiable {
    let id: UUID
    var username: String
    var artistName: String
    var bio: String?
    var profileImageUrl: String?
    var isVerified: Bool
    let createdAt: Date
    var updatedAt: Date
    
    var profileImage: UIImage? {
        // This would be loaded asynchronously in a real implementation
        return nil
    }
}

// MARK: - Errors

enum SupabaseUserError: LocalizedError {
    case connectionFailed
    case usernameCheckFailed
    case usernameNotAvailable
    case usernameReservationFailed
    case userCreationFailed(String)
    case userUpdateFailed
    case noCurrentUser
    case imageProcessingFailed
    case imageUploadFailed
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to connect to server"
        case .usernameCheckFailed:
            return "Could not check username availability"
        case .usernameNotAvailable:
            return "Username is not available"
        case .usernameReservationFailed:
            return "Could not reserve username"
        case .userCreationFailed(let message):
            return "User creation failed: \(message)"
        case .userUpdateFailed:
            return "Failed to update user profile"
        case .noCurrentUser:
            return "No current user"
        case .imageProcessingFailed:
            return "Failed to process image"
        case .imageUploadFailed:
            return "Failed to upload image"
        }
    }
}

// MARK: - Debug Functions

#if DEBUG
extension SupabaseUserManager {
    func debugResetCloudProfile() {
        currentUser = nil
        isProfileSetup = false
        UserDefaults.standard.removeObject(forKey: "CloudUser")
        print("🚧 DEBUG: Cloud profile reset")
    }
    
    func debugUserInfo() {
        print("🚧 DEBUG: Cloud User Manager Status")
        print("   - isConnected: \(isConnected)")
        print("   - isProfileSetup: \(isProfileSetup)")
        print("   - currentUser: \(currentUser?.username ?? "none")")
        print("   - deviceId: \(deviceId)")
    }
    
    func debugConnection() {
        print("🔍 DEBUG: Testing Supabase Connection")
        print("   URL: \(supabaseURL)")
        print("   Key: \(supabaseAnonKey.prefix(20))...")
        
        Task {
            do {
                let url = URL(string: "\(supabaseURL)/rest/v1/")!
                let request = createRequest(url: url)
                
                let (data, response) = try await urlSession.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("   Status: \(httpResponse.statusCode)")
                    
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("   Response: \(responseString.prefix(200))")
                    }
                }
            } catch {
                print("   Error: \(error)")
            }
        }
    }
}
#endif
