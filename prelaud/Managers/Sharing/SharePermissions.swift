//
//  SharePermissions.swift - FIXED DATABASE MAPPING
//  prelaud
//
//  Fixed Codable mapping to match database structure
//

import Foundation

// MARK: - Share Permissions with Database Mapping
struct SharePermissions: Codable {
    let canListen: Bool
    let canDownload: Bool
    let expiresAt: Date?
    
    init(canListen: Bool = true, canDownload: Bool = false, expiresAt: Date? = nil) {
        self.canListen = canListen
        self.canDownload = canDownload
        self.expiresAt = expiresAt
    }
    
    // FIXED: Custom CodingKeys to match database structure
    enum CodingKeys: String, CodingKey {
        case canListen = "can_listen"       // Maps to database field
        case canDownload = "can_download"   // Maps to database field
        case expiresAt = "expires_at"       // Maps to database field
    }
    
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
}

// MARK: - Shared Album Model with Database Mapping
struct SharedAlbum: Codable, Identifiable {
    let id: UUID
    let albumId: UUID
    let ownerId: String
    let ownerUsername: String
    let sharedWithUserId: String
    let shareId: String
    let permissions: SharePermissions
    let createdAt: Date
    let albumTitle: String
    let albumArtist: String
    let songCount: Int
    
    // FIXED: Comprehensive database mapping
    enum CodingKeys: String, CodingKey {
        case id
        case albumId = "album_id"
        case ownerId = "owner_id"
        case ownerUsername = "owner_username"
        case sharedWithUserId = "shared_with_user_id"
        case shareId = "share_id"
        case permissions
        case createdAt = "created_at"
        case albumTitle = "album_title"
        case albumArtist = "album_artist"
        case songCount = "song_count"
    }
    
    // FIXED: Custom decoder for better error handling
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Basic fields
        id = try container.decode(UUID.self, forKey: .id)
        albumId = try container.decode(UUID.self, forKey: .albumId)
        ownerId = try container.decode(String.self, forKey: .ownerId)
        ownerUsername = try container.decode(String.self, forKey: .ownerUsername)
        sharedWithUserId = try container.decode(String.self, forKey: .sharedWithUserId)
        shareId = try container.decode(String.self, forKey: .shareId)
        albumTitle = try container.decode(String.self, forKey: .albumTitle)
        albumArtist = try container.decode(String.self, forKey: .albumArtist)
        songCount = try container.decode(Int.self, forKey: .songCount)
        
        // Date decoding with fallback
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            let formatter = ISO8601DateFormatter()
            createdAt = formatter.date(from: dateString) ?? Date()
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
        
        // Permissions with error handling
        do {
            permissions = try container.decode(SharePermissions.self, forKey: .permissions)
        } catch {
            print("⚠️ Failed to decode permissions, using defaults: \(error)")
            // Fallback to default permissions if decoding fails
            permissions = SharePermissions(canListen: true, canDownload: false)
        }
    }
    
    // Standard initializer
    init(id: UUID, albumId: UUID, ownerId: String, ownerUsername: String, sharedWithUserId: String, shareId: String, permissions: SharePermissions, createdAt: Date, albumTitle: String, albumArtist: String, songCount: Int) {
        self.id = id
        self.albumId = albumId
        self.ownerId = ownerId
        self.ownerUsername = ownerUsername
        self.sharedWithUserId = sharedWithUserId
        self.shareId = shareId
        self.permissions = permissions
        self.createdAt = createdAt
        self.albumTitle = albumTitle
        self.albumArtist = albumArtist
        self.songCount = songCount
    }
}

// MARK: - Alternative: Simple JSON-based SharePermissions
// Use this if the database stores permissions as a simple JSON object
struct SimpleSharePermissions: Codable {
    let canListen: Bool
    let canDownload: Bool
    let expiresAt: String?  // Store as string to avoid date parsing issues
    
    init(canListen: Bool = true, canDownload: Bool = false, expiresAt: String? = nil) {
        self.canListen = canListen
        self.canDownload = canDownload
        self.expiresAt = expiresAt
    }
    
    var isExpired: Bool {
        guard let expiresAtString = expiresAt,
              let expiresAtDate = ISO8601DateFormatter().date(from: expiresAtString) else {
            return false
        }
        return Date() > expiresAtDate
    }
    
    // Convert to SharePermissions
    func toSharePermissions() -> SharePermissions {
        let expiryDate: Date?
        if let expiresAtString = expiresAt {
            expiryDate = ISO8601DateFormatter().date(from: expiresAtString)
        } else {
            expiryDate = nil
        }
        
        return SharePermissions(
            canListen: canListen,
            canDownload: canDownload,
            expiresAt: expiryDate
        )
    }
}

// MARK: - Sharing Errors
enum SharingError: LocalizedError {
    case notLoggedIn
    case userNotFound
    case invalidRequest
    case networkError
    case creationFailed
    case fetchFailed
    case deletionFailed
    case permissionDenied
    case expiredShare
    case decodingError(String)  // NEW: For decoding issues
    
    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "You must be logged in to share albums"
        case .userNotFound:
            return "User not found"
        case .invalidRequest:
            return "Invalid request"
        case .networkError:
            return "Network error occurred"
        case .creationFailed:
            return "Failed to create share"
        case .fetchFailed:
            return "Failed to fetch shared albums"
        case .deletionFailed:
            return "Failed to remove shared album"
        case .permissionDenied:
            return "Permission denied"
        case .expiredShare:
            return "This share has expired"
        case .decodingError(let details):
            return "Data format error: \(details)"
        }
    }
}

// MARK: - Database Helper Functions
extension SharePermissions {
    // Convert to dictionary for database storage
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "can_listen": canListen,
            "can_download": canDownload
        ]
        
        if let expiresAt = expiresAt {
            dict["expires_at"] = ISO8601DateFormatter().string(from: expiresAt)
        }
        
        return dict
    }
    
    // Create from dictionary (for database reading)
    static func fromDictionary(_ dict: [String: Any]) -> SharePermissions {
        let canListen = dict["can_listen"] as? Bool ?? true
        let canDownload = dict["can_download"] as? Bool ?? false
        
        var expiresAt: Date? = nil
        if let expiresAtString = dict["expires_at"] as? String {
            expiresAt = ISO8601DateFormatter().date(from: expiresAtString)
        }
        
        return SharePermissions(
            canListen: canListen,
            canDownload: canDownload,
            expiresAt: expiresAt
        )
    }
}

// MARK: - Debug Helper
extension SharedAlbum {
    func debugDescription() -> String {
        return """
        SharedAlbum Debug:
        - ID: \(id)
        - Album: \(albumTitle) by \(albumArtist)
        - Owner: @\(ownerUsername)
        - ShareID: \(shareId)
        - Permissions: Listen=\(permissions.canListen), Download=\(permissions.canDownload)
        - Created: \(createdAt)
        """
    }
}
