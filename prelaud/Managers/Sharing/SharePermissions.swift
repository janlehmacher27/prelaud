//
//  SharePermissions.swift
//  prelaud
//
//  Created by Jan Lehmacher on 15.07.25.
//


//
//  SharePermissions.swift
//  prelaud
//
//  Datenmodelle für Album-Sharing
//

import Foundation

// MARK: - Share Permissions
struct SharePermissions: Codable {
    let canListen: Bool
    let canDownload: Bool
    let expiresAt: Date?
    
    init(canListen: Bool = true, canDownload: Bool = false, expiresAt: Date? = nil) {
        self.canListen = canListen
        self.canDownload = canDownload
        self.expiresAt = expiresAt
    }
    
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
}

// MARK: - Shared Album Model
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
    
    // Für Supabase
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
        }
    }
}