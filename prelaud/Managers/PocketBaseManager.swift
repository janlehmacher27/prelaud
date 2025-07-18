//
//  PocketBaseManager.swift - KOMPLETTE SAUBERE VERSION
//  prelaud
//
//  Alle Methoden in einer Klasse, keine Duplikate
//

import Foundation
import UIKit

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
        
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            let user = try parseUserFromData(responseData)
            print("✅ User created successfully: \(user.id)")
            return user
        } else {
            let errorMessage = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            print("❌ User creation failed: \(httpResponse.statusCode) - \(errorMessage)")
            throw PBError.creationFailed
        }
    }
    
    func getUserByUsername(_ username: String) async throws -> PBUser? {
        print("🔍 Looking up user: @\(username)")
        
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
                print("✅ Found user: @\(user.username)")
                return user
            } else {
                print("❌ User not found: @\(username)")
                return nil
            }
        } else {
            throw PBError.fetchFailed
        }
    }
    
    func getUserById(_ userId: String) async throws -> PBUser {
        print("🔍 Looking up user by ID: \(userId)")
        
        let url = URL(string: "\(baseURL)/api/collections/users/records/\(userId)")!
        let request = createRequest(url: url)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PBError.networkError
        }
        
        if httpResponse.statusCode == 200 {
            let user = try parseUserFromData(data)
            print("✅ Found user by ID: @\(user.username)")
            return user
        } else {
            print("❌ User not found with ID: \(userId)")
            throw PBError.userNotFound
        }
    }
    
    func checkUsernameAvailability(_ username: String) async throws -> PBUsernameCheckResult {
        print("🔍 Checking username availability: \(username)")
        
        do {
            let user = try await getUserByUsername(username)
            if user != nil {
                return PBUsernameCheckResult(isValid: false, errorMessage: "Username already taken")
            } else {
                return PBUsernameCheckResult(isValid: true, errorMessage: nil)
            }
        } catch {
            if error is PBError {
                return PBUsernameCheckResult(isValid: false, errorMessage: "Error checking username")
            }
            throw error
        }
    }
    
    // MARK: - Audio File Management
    
    func uploadAudioFile(data: Data, filename: String, songId: String) async throws -> String {
        print("🎵 Uploading audio file to PocketBase: \(filename)")
        
        let ownerId = getCurrentUserId()
        
        let url = URL(string: "\(baseURL)/api/collections/audio_files/records")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add metadata
        let metadata = [
            "song_id": songId,
            "filename": filename,
            "owner_id": ownerId
        ]
        
        for (key, value) in metadata {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add audio file
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
        
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
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
        
        // Check if ownerId is valid
        guard !ownerId.isEmpty && ownerId != "anonymous" else {
            print("❌ Invalid owner ID: \(ownerId)")
            throw PBError.notLoggedIn
        }
        
        print("📋 Upload details:")
        print("  - Owner ID: \(ownerId)")
        print("  - Song ID: \(songId)")
        print("  - Display Name: \(displayName)")
        print("  - File size: \(audioData.count) bytes")
        
        let url = URL(string: "\(baseURL)/api/collections/audio_files/records")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add required fields - adjust these to match your PocketBase schema
        let formFields = [
            "owner": ownerId,              // Change from "owner_id" to "owner"
            "song_id": songId,
            "filename": filename,
            "display_name": displayName,
            "uploaded_at": uploadedAt
        ]
        
        // Add form fields for metadata
        for (key, value) in formFields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add file data - change field name to match schema
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mpeg\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (responseData, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PBError.networkError
        }
        
        print("📡 Response status: \(httpResponse.statusCode)")
        
        if let responseString = String(data: responseData, encoding: .utf8) {
            print("📄 Response body: \(responseString)")
        }
        
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
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
    
    func saveAlbumWithCoverToPocketBase(_ album: Album, coverImageData: Data) async throws -> String {
        print("💾 Saving album to PocketBase: \(album.title)")
        
        let ownerId = getCurrentUserId()
        
        // Validate owner ID
        guard !ownerId.isEmpty && !ownerId.contains("anonymous") else {
            print("❌ Invalid owner ID for album upload: \(ownerId)")
            throw PBError.notLoggedIn
        }
        
        // Create album metadata - adjust field names to match PocketBase schema
        let albumData: [String: Any] = [
            "title": album.title,
            "artist": album.artist,
            "release_date": ISO8601DateFormatter().string(from: album.releaseDate),
            "owner": ownerId,           // Change from "owner_id" to "owner"
            "song_count": album.songs.count
        ]
        
        print("📋 Album upload details:")
        print("  - Title: \(album.title)")
        print("  - Artist: \(album.artist)")
        print("  - Owner: \(ownerId)")
        print("  - Song count: \(album.songs.count)")
        print("  - Cover image size: \(coverImageData.count) bytes")
        
        let url = URL(string: "\(baseURL)/api/collections/albums/records")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add album metadata
        for (key, value) in albumData {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add cover image if provided
        if !coverImageData.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"cover\"; filename=\"cover.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(coverImageData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PBError.networkError
        }
        
        print("📡 Album upload response status: \(httpResponse.statusCode)")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 Album upload response: \(responseString)")
        }
        
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let albumId = json["id"] as? String {
                print("✅ Album saved to PocketBase: \(albumId)")
                return albumId
            }
        }
        
        // Better error handling
        let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        print("❌ Album creation failed: \(httpResponse.statusCode) - \(errorMessage)")
        throw PBError.creationFailed
    }
    
    func cascadeDeleteAlbum(_ album: Album) async throws {
        print("🗑️ Starting cascade delete for album: \(album.title)")
        
        // First, try to find the album in PocketBase
        let ownerId = getCurrentUserId()
        let encodedOwnerId = ownerId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ownerId
        let encodedTitle = album.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? album.title
        
        let searchUrl = URL(string: "\(baseURL)/api/collections/albums/records?filter=owner_id='\(encodedOwnerId)'%26%26title='\(encodedTitle)'")!
        let searchRequest = createRequest(url: searchUrl)
        
        let (searchData, searchResponse) = try await urlSession.data(for: searchRequest)
        
        guard let httpSearchResponse = searchResponse as? HTTPURLResponse,
              httpSearchResponse.statusCode == 200 else {
            throw PBError.fetchFailed
        }
        
        if let searchResult = try JSONSerialization.jsonObject(with: searchData) as? [String: Any],
           let items = searchResult["items"] as? [[String: Any]],
           let firstItem = items.first,
           let albumId = firstItem["id"] as? String {
            
            // Delete the album record
            let deleteUrl = URL(string: "\(baseURL)/api/collections/albums/records/\(albumId)")!
            var deleteRequest = URLRequest(url: deleteUrl)
            deleteRequest.httpMethod = "DELETE"
            
            let (_, deleteResponse) = try await urlSession.data(for: deleteRequest)
            
            guard let httpDeleteResponse = deleteResponse as? HTTPURLResponse,
                  (200...299).contains(httpDeleteResponse.statusCode) else {
                throw PBError.deletionFailed
            }
            
            print("✅ Album cascade deleted from PocketBase: \(albumId)")
        } else {
            print("⚠️ Album not found in PocketBase for deletion")
        }
    }
    
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
        guard let title = dict["title"] as? String,
              let artist = dict["artist"] as? String else {
            throw PBError.fetchFailed
        }
        
        let releaseDateString = dict["release_date"] as? String ?? ""
        let releaseDate: Date
        if !releaseDateString.isEmpty {
            releaseDate = ISO8601DateFormatter().date(from: releaseDateString) ?? Date()
        } else {
            releaseDate = Date()
        }
        
        // Create album with empty songs array for now
        // Songs would need to be loaded separately in a full implementation
        var album = Album(
            title: title,
            artist: artist,
            songs: [], // TODO: Load songs separately
            coverImage: nil, // TODO: Load cover image separately
            releaseDate: releaseDate
        )
        
        // Set owner info if available
        album.ownerId = dict["owner_id"] as? String
        album.ownerUsername = dict["owner_username"] as? String
        
        return album
    }
    
    // MARK: - Properties for compatibility
    
    var isConnected: Bool {
        return !baseURL.isEmpty
    }
}

// MARK: - Data Models

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
