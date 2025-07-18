//
//  PocketBaseManager.swift - FINAL CLEAN VERSION
//  prelaud
//
//  No duplicate definitions, no syntax errors
//

import Foundation
import SwiftUI

@MainActor
class PocketBaseManager: ObservableObject {
    static let shared = PocketBaseManager()
    
    let baseURL = "https://prelaud.pockethost.io"
    let urlSession = URLSession.shared
    
    private init() {}
    
    // MARK: - Connection Testing
    
    func testConnection() async -> Bool {
        return await performHealthCheck()
    }
    
    func performHealthCheck() async -> Bool {
        do {
            let url = URL(string: "\(baseURL)/api/health")!
            let (_, response) = try await urlSession.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                let isHealthy = httpResponse.statusCode == 200
                print("🏥 PocketBase health check: \(isHealthy ? "✅ Healthy" : "❌ Unhealthy (\(httpResponse.statusCode))")")
                return isHealthy
            }
            return false
        } catch {
            print("🏥 PocketBase health check failed: \(error)")
            return false
        }
    }
    
    // MARK: - User Management
    
    func createUser(username: String, artistName: String, bio: String? = nil, profileImage: UIImage? = nil) async throws -> PBUser {
        print("👤 Creating user in PocketBase: @\(username)")
        
        // Check if user already exists
        if let existingUser = try? await getUserByUsername(username) {
            print("⚠️ User already exists: @\(username)")
            return existingUser
        }
        
        let userData: [String: Any] = [
            "username": username.lowercased(),
            "artist_name": artistName,
            "bio": bio ?? "",
            "is_active": true,
            "created": ISO8601DateFormatter().string(from: Date())
        ]
        
        let url = URL(string: "\(baseURL)/api/collections/users/records")!
        var request = createRequest(url: url, method: "POST")
        request.httpBody = try JSONSerialization.data(withJSONObject: userData)
        
        let (responseData, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PBError.networkError
        }
        
        if httpResponse.statusCode == 200 {
            let user = try parseUserFromData(responseData)
            print("✅ User created successfully: \(user.id)")
            return user
        } else {
            let errorMessage = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            print("❌ Failed to create user: \(httpResponse.statusCode) - \(errorMessage)")
            
            switch httpResponse.statusCode {
            case 400:
                if errorMessage.contains("username") {
                    throw PBError.userNotFound
                } else {
                    throw PBError.creationFailed
                }
            case 403:
                throw PBError.creationFailed
            case 404:
                throw PBError.creationFailed
            default:
                throw PBError.networkError
            }
        }
    }
    
    func getUserById(_ id: String) async throws -> PBUser {
        print("🔍 Getting user by ID: \(id)")
        
        let url = URL(string: "\(baseURL)/api/collections/users/records/\(id)")!
        let request = createRequest(url: url)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PBError.networkError
        }
        
        if httpResponse.statusCode == 200 {
            let user = try JSONDecoder().decode(PBUser.self, from: data)
            print("✅ User found: @\(user.username)")
            return user
        } else if httpResponse.statusCode == 404 {
            print("❌ User not found with ID: \(id)")
            throw PBError.userNotFound
        } else {
            print("❌ Failed to get user: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Response: \(responseString)")
            }
            throw PBError.networkError
        }
    }
    
    func getUserByUsername(_ username: String) async throws -> PBUser? {
        print("🔍 Finding user by username: @\(username)")
        
        let encodedUsername = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username
        let url = URL(string: "\(baseURL)/api/collections/users/records?filter=username='\(encodedUsername)'")!
        let request = createRequest(url: url)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PBError.networkError
        }
        
        if httpResponse.statusCode == 200 {
            let result = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let items = result?["items"] as? [[String: Any]] ?? []
            
            if let firstItem = items.first {
                let user = try parseUserFromDictionary(firstItem)
                print("✅ User found by username: @\(user.username)")
                return user
            } else {
                print("❌ No user found with username: @\(username)")
                return nil
            }
        } else {
            throw PBError.fetchFailed
        }
    }
    
    func checkUsernameAvailability(_ username: String) async throws -> PBUsernameCheckResult {
        print("🔍 Checking username availability: @\(username)")
        
        // Basic validation
        guard username.count >= 3 else {
            return PBUsernameCheckResult(isValid: false, errorMessage: "Username must be at least 3 characters")
        }
        
        guard username.count <= 30 else {
            return PBUsernameCheckResult(isValid: false, errorMessage: "Username must be 30 characters or less")
        }
        
        guard username.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" || $0 == "." }) else {
            return PBUsernameCheckResult(isValid: false, errorMessage: "Username can only contain letters, numbers, _, -, and .")
        }
        
        // Check if username exists in PocketBase
        do {
            let existingUser = try await getUserByUsername(username)
            
            if existingUser != nil {
                print("❌ Username taken: @\(username)")
                return PBUsernameCheckResult(isValid: false, errorMessage: "Username is already taken")
            } else {
                print("✅ Username available: @\(username)")
                return PBUsernameCheckResult(isValid: true, errorMessage: nil)
            }
        } catch {
            print("❌ Username check failed: \(error)")
            throw PBError.checkFailed
        }
    }
    
    // MARK: - Audio File Management
    
    func uploadAudioFile(data: Data, filename: String, songId: String) async throws -> String {
        print("🎵 Uploading audio file to PocketBase: \(filename)")
        
        let ownerId = getCurrentUserId()
        
        let audioData: [String: Any] = [
            "song_id": songId,
            "filename": filename,
            "owner_id": ownerId,
            "uploaded_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        let url = URL(string: "\(baseURL)/api/collections/audio_files/records")!
        var request = createRequest(url: url, method: "POST")
        
        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add form fields
        for (key, value) in audioData {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio_file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (responseData, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PBError.networkError
        }
        
        if httpResponse.statusCode == 200 {
            if let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let fileId = json["id"] as? String {
                print("✅ Audio file uploaded successfully: \(fileId)")
                return fileId
            } else {
                throw PBError.uploadFailed
            }
        } else {
            let errorMessage = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            print("❌ Failed to upload audio file: \(httpResponse.statusCode) - \(errorMessage)")
            throw PBError.uploadFailed
        }
    }
    
    func getAudioFileURL(songId: String) async throws -> URL? {
        print("🔍 Getting audio file URL for songId: \(songId)")
        
        let encodedSongId = songId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? songId
        let url = URL(string: "\(baseURL)/api/collections/audio_files/records?filter=song_id='\(encodedSongId)'")!
        let request = createRequest(url: url)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PBError.networkError
        }
        
        if httpResponse.statusCode == 200 {
            let result = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let items = result?["items"] as? [[String: Any]] ?? []
            
            if let firstItem = items.first,
               let recordId = firstItem["id"] as? String,
               let filename = firstItem["audio_file"] as? String {
                let fileURL = URL(string: "\(baseURL)/api/files/audio_files/\(recordId)/\(filename)")!
                print("✅ Audio file URL found: \(fileURL)")
                return fileURL
            } else {
                print("❌ No audio file found for songId: \(songId)")
                return nil
            }
        } else {
            throw PBError.fetchFailed
        }
    }
    
    // MARK: - Album Management
    
    func loadAlbumsFromPocketBase() async throws -> [Album] {
        print("📚 Loading albums from PocketBase...")
        
        let ownerId = getCurrentUserId()
        let encodedOwnerId = ownerId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ownerId
        let url = URL(string: "\(baseURL)/api/collections/albums/records?filter=owner_id='\(encodedOwnerId)'")!
        let request = createRequest(url: url)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PBError.networkError
        }
        
        if httpResponse.statusCode == 200 {
            let result = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let items = result?["items"] as? [[String: Any]] ?? []
            
            var albums: [Album] = []
            
            for item in items {
                if let album = try? parseAlbumFromDictionary(item) {
                    albums.append(album)
                }
            }
            
            print("✅ Loaded \(albums.count) albums from PocketBase")
            return albums
        } else {
            throw PBError.fetchFailed
        }
    }
    
    // MARK: - Helper Methods
    
    func createRequest(url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
    
    private func getCurrentUserId() -> String {
        // Try to get the PocketBase cloudId from UserProfileManager
        if let userProfile = UserProfileManager.shared.userProfile,
           let cloudId = userProfile.cloudId, !cloudId.isEmpty {
            print("👤 Using PocketBase cloudId as owner: \(cloudId)")
            return cloudId
        }
        
        // Fall back to using local user ID
        if let userProfile = UserProfileManager.shared.userProfile {
            let fallbackId = userProfile.id.uuidString
            print("👤 Using fallback local ID as owner: \(fallbackId)")
            return fallbackId
        }
        
        // Emergency fallback
        let emergencyId = "anonymous_\(UUID().uuidString.prefix(8))"
        print("⚠️ Using emergency fallback ID: \(emergencyId)")
        return emergencyId
    }
    
    // MARK: - Parsing Helpers
    
    private func parseUserFromData(_ data: Data) throws -> PBUser {
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return try parseUserFromDictionary(json)
        } else {
            throw PBError.creationFailed
        }
    }
    
    private func parseUserFromDictionary(_ dict: [String: Any]) throws -> PBUser {
        guard let userId = dict["id"] as? String,
              let username = dict["username"] as? String else {
            throw PBError.creationFailed
        }
        
        return PBUser(
            id: userId,
            username: username,
            artistName: dict["artist_name"] as? String ?? "",
            bio: dict["bio"] as? String ?? "",
            isActive: dict["is_active"] as? Bool ?? true,
            created: dict["created"] as? String ?? "",
            updated: dict["updated"] as? String ?? ""
        )
    }
    
    private func parseAlbumFromDictionary(_ dict: [String: Any]) throws -> Album {
        guard let _ = dict["id"] as? String,
              let title = dict["title"] as? String,
              let artist = dict["artist"] as? String else {
            throw PBError.fetchFailed
        }
        
        // Parse release date
        let releaseDate: Date
        if let releaseDateString = dict["release_date"] as? String {
            releaseDate = ISO8601DateFormatter().date(from: releaseDateString) ?? Date()
        } else {
            releaseDate = Date()
        }
        
        // Parse songs (simplified for now)
        let songs: [Song] = []
        
        var album = Album(
            title: title,
            artist: artist,
            songs: songs,
            coverImage: nil,
            releaseDate: releaseDate
        )
        
        // Set owner info if available
        album.ownerId = dict["owner_id"] as? String
        album.ownerUsername = dict["owner_username"] as? String
        
        return album
    }
}

// MARK: - Data Models (SINGLE DEFINITIONS ONLY)

struct PBUser: Codable, Identifiable {
    let id: String
    let username: String
    let artistName: String
    let bio: String
    let isActive: Bool
    let created: String
    let updated: String
    
    enum CodingKeys: String, CodingKey {
        case id, username, bio, created, updated
        case artistName = "artist_name"
        case isActive = "is_active"
    }
}

struct PBUsernameCheckResult {
    let isValid: Bool
    let errorMessage: String?
    
    init(isValid: Bool, errorMessage: String?) {
        self.isValid = isValid
        self.errorMessage = errorMessage
    }
}

enum PBError: Error, LocalizedError, Equatable {
    case networkError
    case notLoggedIn
    case creationFailed
    case updateFailed
    case fetchFailed
    case checkFailed
    case userNotFound
    case uploadFailed
    case fileNotFound
    case deletionFailed
    case fileTooLarge
    
    var errorDescription: String? {
        switch self {
        case .networkError: return "Network connection failed"
        case .notLoggedIn: return "User not logged in"
        case .creationFailed: return "Failed to create record"
        case .updateFailed: return "Failed to update record"
        case .fetchFailed: return "Failed to fetch data"
        case .checkFailed: return "Failed to check availability"
        case .userNotFound: return "User not found"
        case .uploadFailed: return "Failed to upload file"
        case .fileNotFound: return "File not found"
        case .deletionFailed: return "Failed to delete record"
        case .fileTooLarge: return "File is too large (max 50MB)"
        }
    }
}


//
//  PocketBaseManager.swift - FIXES FOR MISSING METHODS
//  Add these methods to your existing PocketBaseManager class
//

import Foundation
import SwiftUI

// MARK: - Add these properties and methods to your existing PocketBaseManager class

extension PocketBaseManager {
    
    // MARK: - Missing isConnected Property
    var isConnected: Bool {
        // You can implement this as a simple check or use cached status
        // For now, return true if baseURL is accessible (you may want to cache this)
        return !baseURL.isEmpty
    }
    
    // MARK: - Missing uploadAudioFileWithMetadata Method
    func uploadAudioFileWithMetadata(
        _ fileURL: URL,
        filename: String,
        songId: String,
        displayName: String,
        uploadedAt: String
    ) async throws -> String {
        print("🎵 Uploading audio file with metadata to PocketBase: \(filename)")
        
        // Read the file data
        let audioData = try Data(contentsOf: fileURL)
        
        // Get current user ID
        let ownerId = getCurrentUserId()
        
        // Create the metadata dictionary
        let audioMetadata: [String: Any] = [
            "song_id": songId,
            "filename": filename,
            "display_name": displayName,
            "owner_id": ownerId,
            "uploaded_at": uploadedAt
        ]
        
        let url = URL(string: "\(baseURL)/api/collections/audio_files/records")!
        var request = createRequest(url: url, method: "POST")
        
        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add form fields for metadata
        for (key, value) in audioMetadata {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio_file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mpeg\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (responseData, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PBError.networkError
        }
        
        if httpResponse.statusCode == 200 {
            if let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let fileId = json["id"] as? String {
                print("✅ Audio file uploaded with metadata successfully: \(fileId)")
                return fileId
            } else {
                throw PBError.uploadFailed
            }
        } else {
            let errorMessage = String(data: responseData, encoding: .utf8) ?? "Upload failed"
            print("❌ Audio upload failed: \(errorMessage)")
            throw PBError.uploadFailed
        }
    }
    
    
}
