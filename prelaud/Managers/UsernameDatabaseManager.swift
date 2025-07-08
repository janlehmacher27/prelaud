//
//  UsernameDatabaseManager.swift - COMPLETELY REWRITTEN
//  prelaud
//
//  Unified user management with single 'users' table - MUCH SIMPLER!
//

import Foundation
import SwiftUI

@MainActor
class UsernameDatabaseManager: ObservableObject {
    static let shared = UsernameDatabaseManager()
    
    // Supabase Configuration
    private let supabaseURL = "https://auzsunnwanzljiwdpzov.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1enN1bm53YW56bGppd2Rwem92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIxMzIyNjksImV4cCI6MjA2NzcwODI2OX0.UmuoVT-7uXq5SMFr9duiurbE52Oe865w4ghYPkFwexE"
    
    private var urlSession: URLSession
    
    // Local cache
    @Published var takenUsernames: Set<String> = []
    @Published var isLoadingCache = false
    
    // Reserved usernames
    private let reservedUsernames: Set<String> = [
        "admin", "root", "api", "www", "mail", "ftp", "prelaud", "support",
        "help", "info", "contact", "about", "privacy", "terms", "legal",
        "music", "spotify", "apple", "amazon", "youtube", "official"
    ]
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        urlSession = URLSession(configuration: config)
        loadUsernameCache()
    }
    
    // MARK: - Request Helper
    
    private func createRequest(url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
    
    // MARK: - User Operations
    
    /// Creates a new user with unique username and artist name
    func registerUsername(_ username: String, userId: String, artistName: String? = nil, bio: String? = nil, profileImageUrl: String? = nil) async throws {
        print("👤 Creating user with username: @\(username), artist: \(artistName ?? "Unknown")")
        
        // Check username availability first
        let isAvailable = try await checkUsernameAvailability(username)
        guard isAvailable else {
            throw DatabaseError.usernameNotAvailable
        }
        
        // Create user with proper data
        let userData: [String: Any] = [
            "id": userId,
            "username": username.lowercased(),
            "artist_name": artistName ?? "Artist", // Use provided artist name
            "bio": bio ?? NSNull(),
            "profile_image_url": profileImageUrl ?? NSNull()
        ]
        
        let endpoint = "\(supabaseURL)/rest/v1/users"
        guard let url = URL(string: endpoint) else {
            throw DatabaseError.invalidURL
        }
        
        var request = createRequest(url: url, method: "POST")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: userData)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.networkError
        }
        
        print("📋 Create user response: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 201 {
            // Update local cache
            takenUsernames.insert(username.lowercased())
            print("✅ User created successfully: @\(username)")
            
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ User creation failed: \(httpResponse.statusCode) - \(errorMessage)")
            throw DatabaseError.registrationFailed
        }
    }
    
    /// Updates user information (including username change)
    func changeUsername(from oldUsername: String, to newUsername: String, userId: String) async throws {
        print("🔄 Changing username: \(oldUsername) → \(newUsername)")
        
        // Check new username availability
        let isAvailable = try await checkUsernameAvailability(newUsername)
        guard isAvailable else {
            throw DatabaseError.usernameNotAvailable
        }
        
        let updateData: [String: Any] = [
            "username": newUsername.lowercased(),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        let endpoint = "\(supabaseURL)/rest/v1/users?id=eq.\(userId)"
        guard let url = URL(string: endpoint) else {
            throw DatabaseError.invalidURL
        }
        
        var request = createRequest(url: url, method: "PATCH")
        request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.networkError
        }
        
        print("📋 Change username response: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 204 {
            // Update local cache
            takenUsernames.remove(oldUsername.lowercased())
            takenUsernames.insert(newUsername.lowercased())
            
            print("✅ Username changed successfully: \(oldUsername) → \(newUsername)")
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Username change failed: \(httpResponse.statusCode) - \(errorMessage)")
            throw DatabaseError.releaseFailed
        }
    }
    
    /// Universal update function - updates any combination of user data
    func updateUser(userId: String, username: String? = nil, artistName: String? = nil, bio: String? = nil, profileImageUrl: String? = nil) async throws {
        print("🔄 Updating user: \(userId)")
        
        var updateData: [String: Any] = [
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Handle username change (requires availability check)
        if let newUsername = username {
            let isAvailable = try await checkUsernameAvailability(newUsername)
            guard isAvailable else {
                throw DatabaseError.usernameNotAvailable
            }
            updateData["username"] = newUsername.lowercased()
        }
        
        // Add other updates
        if let artistName = artistName { updateData["artist_name"] = artistName }
        if let bio = bio { updateData["bio"] = bio }
        if let profileImageUrl = profileImageUrl { updateData["profile_image_url"] = profileImageUrl }
        
        // Nothing to update?
        guard updateData.count > 1 else {
            print("No changes to update")
            return
        }
        
        let endpoint = "\(supabaseURL)/rest/v1/users?id=eq.\(userId)"
        guard let url = URL(string: endpoint) else {
            throw DatabaseError.invalidURL
        }
        
        var request = createRequest(url: url, method: "PATCH")
        request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.networkError
        }
        
        print("📋 Update user response: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 204 {
            // Update local cache if username changed
            if let newUsername = username {
                takenUsernames.insert(newUsername.lowercased())
            }
            
            print("✅ User updated successfully")
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ User update failed: \(httpResponse.statusCode) - \(errorMessage)")
            throw DatabaseError.releaseFailed
        }
    }
    
    /// Gets user by ID
    func getUser(byId userId: String) async throws -> DatabaseUser {
        let endpoint = "\(supabaseURL)/rest/v1/users?id=eq.\(userId)&select=*"
        guard let url = URL(string: endpoint) else {
            throw DatabaseError.invalidURL
        }
        
        let request = createRequest(url: url, method: "GET")
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.networkError
        }
        
        if httpResponse.statusCode == 200 {
            let users = try JSONDecoder().decode([DatabaseUser].self, from: data)
            guard let user = users.first else {
                throw DatabaseError.userNotFound
            }
            return user
        } else {
            throw DatabaseError.userNotFound
        }
    }
    
    /// Gets user by username
    func getUser(byUsername username: String) async throws -> DatabaseUser {
        let endpoint = "\(supabaseURL)/rest/v1/users?username=eq.\(username.lowercased())&select=*"
        guard let url = URL(string: endpoint) else {
            throw DatabaseError.invalidURL
        }
        
        let request = createRequest(url: url, method: "GET")
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.networkError
        }
        
        if httpResponse.statusCode == 200 {
            let users = try JSONDecoder().decode([DatabaseUser].self, from: data)
            guard let user = users.first else {
                throw DatabaseError.userNotFound
            }
            return user
        } else {
            throw DatabaseError.userNotFound
        }
    }
    
    /// Checks if username is available - SIMPLIFIED!
    func checkUsernameAvailability(_ username: String) async throws -> Bool {
        let normalizedUsername = username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🔍 Checking username availability: \(normalizedUsername)")
        
        // Check reserved usernames
        if reservedUsernames.contains(normalizedUsername) {
            print("❌ Username reserved: \(normalizedUsername)")
            return false
        }
        
        // Check local cache first
        if takenUsernames.contains(normalizedUsername) {
            print("❌ Username taken (cached): \(normalizedUsername)")
            return false
        }
        
        // Check database - MUCH SIMPLER now!
        let endpoint = "\(supabaseURL)/rest/v1/users?username=eq.\(normalizedUsername)&is_active=eq.true&select=username"
        guard let url = URL(string: endpoint) else {
            throw DatabaseError.invalidURL
        }
        
        let request = createRequest(url: url, method: "GET")
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.networkError
        }
        
        print("📋 Username check response: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let users = try JSONDecoder().decode([UsernameLookup].self, from: data)
            let isAvailable = users.isEmpty
            
            if !isAvailable {
                takenUsernames.insert(normalizedUsername)
            }
            
            print(isAvailable ? "✅ Username available: \(normalizedUsername)" : "❌ Username taken: \(normalizedUsername)")
            return isAvailable
            
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Username check failed: \(httpResponse.statusCode) - \(errorMessage)")
            throw DatabaseError.checkFailed
        }
    }
    
    /// Updates user profile information
    func updateUserProfile(userId: String, artistName: String? = nil, bio: String? = nil, profileImageUrl: String? = nil) async throws {
        print("🔄 Updating user profile: \(userId)")
        
        var updateData: [String: Any] = [
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        if let artistName = artistName { updateData["artist_name"] = artistName }
        if let bio = bio { updateData["bio"] = bio }
        if let profileImageUrl = profileImageUrl { updateData["profile_image_url"] = profileImageUrl }
        
        let endpoint = "\(supabaseURL)/rest/v1/users?id=eq.\(userId)"
        guard let url = URL(string: endpoint) else {
            throw DatabaseError.invalidURL
        }
        
        var request = createRequest(url: url, method: "PATCH")
        request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.networkError
        }
        
        if httpResponse.statusCode == 204 {
            print("✅ User profile updated successfully")
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ User profile update failed: \(httpResponse.statusCode) - \(errorMessage)")
            throw DatabaseError.releaseFailed
        }
    }
    
    /// Releases username (deactivates user)
    func releaseUsername(_ username: String, userId: String) async throws {
        print("🔓 Deactivating user: \(username)")
        
        let updateData: [String: Any] = [
            "is_active": false,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        let endpoint = "\(supabaseURL)/rest/v1/users?id=eq.\(userId)"
        guard let url = URL(string: endpoint) else {
            throw DatabaseError.invalidURL
        }
        
        var request = createRequest(url: url, method: "PATCH")
        request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.networkError
        }
        
        if httpResponse.statusCode == 204 {
            // Remove from local cache
            takenUsernames.remove(username.lowercased())
            print("✅ User deactivated successfully")
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ User deactivation failed: \(httpResponse.statusCode) - \(errorMessage)")
            throw DatabaseError.releaseFailed
        }
    }
    
    // MARK: - Cache Management - SIMPLIFIED!
    
    private func loadUsernameCache() {
        Task {
            await MainActor.run {
                isLoadingCache = true
            }
            
            do {
                let usernames = try await fetchAllUsernames()
                
                await MainActor.run {
                    self.takenUsernames = Set(usernames.map { $0.lowercased() })
                    self.isLoadingCache = false
                    print("📂 Loaded \(usernames.count) usernames into cache")
                }
            } catch {
                await MainActor.run {
                    self.takenUsernames = self.reservedUsernames
                    self.isLoadingCache = false
                    print("⚠️ Cache loading failed, using reserved usernames: \(error)")
                }
            }
        }
    }
    
    private func fetchAllUsernames() async throws -> [String] {
        let endpoint = "\(supabaseURL)/rest/v1/users?is_active=eq.true&select=username"
        guard let url = URL(string: endpoint) else {
            throw DatabaseError.invalidURL
        }
        
        let request = createRequest(url: url, method: "GET")
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatabaseError.networkError
        }
        
        if httpResponse.statusCode == 200 {
            let users = try JSONDecoder().decode([UsernameLookup].self, from: data)
            return users.map { $0.username }
        } else {
            throw DatabaseError.fetchFailed
        }
    }
    
    func refreshCache() {
        loadUsernameCache()
    }
    
    func clearCache() {
        takenUsernames.removeAll()
    }
}

// MARK: - Data Models

struct DatabaseUser: Codable, Identifiable {
    let id: UUID
    let username: String
    let artistName: String
    let bio: String?
    let profileImageUrl: String?
    let createdAt: Date
    let updatedAt: Date
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case artistName = "artist_name"
        case bio
        case profileImageUrl = "profile_image_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isActive = "is_active"
    }
}

struct UsernameLookup: Codable {
    let username: String
}

// MARK: - Errors (same as before)

enum DatabaseError: LocalizedError {
    case invalidURL
    case networkError
    case registrationFailed
    case releaseFailed
    case checkFailed
    case fetchFailed
    case usernameNotAvailable
    case userNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid database URL"
        case .networkError:
            return "Network connection failed"
        case .registrationFailed:
            return "Failed to register username"
        case .releaseFailed:
            return "Failed to release username"
        case .checkFailed:
            return "Failed to check username availability"
        case .fetchFailed:
            return "Failed to fetch data"
        case .usernameNotAvailable:
            return "Username is not available"
        case .userNotFound:
            return "User not found"
        }
    }
}

// MARK: - Usage Examples

/*
// UPDATED USAGE EXAMPLES:

// 1. Check username
let isAvailable = try await UsernameDatabaseManager.shared.checkUsernameAvailability("newusername")

// 2. Register user with artist name
try await UsernameDatabaseManager.shared.registerUsername(
    "newusername",
    userId: "uuid-here",
    artistName: "My Artist Name",
    bio: "Optional bio"
)

// 3. Change username (atomic!)
try await UsernameDatabaseManager.shared.changeUsername(
    from: "oldusername",
    to: "newusername",
    userId: "uuid-here"
)

// 4. Update profile
try await UsernameDatabaseManager.shared.updateUserProfile(
    userId: "uuid-here",
    artistName: "New Artist Name",
    bio: "Updated bio"
)

// 5. Get user
let user = try await UsernameDatabaseManager.shared.getUser(byUsername: "username")
*/
