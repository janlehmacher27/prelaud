//
//  SharedModels.swift - FIXED FÜR POCKETBASE IDS
//  prelaud
//
//  FIXED: SharingRequest unterstützt jetzt PocketBase IDs
//

import Foundation

// MARK: - FIXED: Sharing Models mit PocketBase ID Support

struct SharingRequest: Identifiable, Codable {
    let id: UUID                    // Lokale UUID für SwiftUI
    let pocketBaseId: String        // FIXED: PocketBase ID (fruloqlgg0qq330, etc.)
    let shareId: String
    let fromUserId: String
    let fromUsername: String
    let toUserId: String
    let albumId: UUID
    let albumTitle: String
    let albumArtist: String
    let songCount: Int
    let permissions: SharePermissions
    let createdAt: Date
    var isRead: Bool
    var status: SharingRequestStatus
    
    init(id: UUID, pocketBaseId: String, shareId: String, fromUserId: String, fromUsername: String, toUserId: String, albumId: UUID, albumTitle: String, albumArtist: String, songCount: Int, permissions: SharePermissions, createdAt: Date, isRead: Bool, status: SharingRequestStatus) {
        self.id = id
        self.pocketBaseId = pocketBaseId  // FIXED: PocketBase ID hinzugefügt
        self.shareId = shareId
        self.fromUserId = fromUserId
        self.fromUsername = fromUsername
        self.toUserId = toUserId
        self.albumId = albumId
        self.albumTitle = albumTitle
        self.albumArtist = albumArtist
        self.songCount = songCount
        self.permissions = permissions
        self.createdAt = createdAt
        self.isRead = isRead
        self.status = status
    }
}

enum SharingRequestStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case approved = "approved"  // FIXED: war "accepted"
    case rejected = "rejected"  // FIXED: war "declined"
}

struct SharePermissions: Codable {
    let canListen: Bool
    let canDownload: Bool
    let expiresAt: Date?
    
    init(canListen: Bool = true, canDownload: Bool = false, expiresAt: Date? = nil) {
        self.canListen = canListen
        self.canDownload = canDownload
        self.expiresAt = expiresAt
    }
}

// MARK: - Error Types (unverändert)

enum SharingError: Error, LocalizedError {
    case userNotValid
    case userNotFound
    case networkError
    case creationFailed
    case fetchFailed
    case invalidResponse
    case updateFailed
    case invalidRequest
    
    var errorDescription: String? {
        switch self {
        case .userNotValid: return "Current user is not properly configured"
        case .userNotFound: return "Target user not found"
        case .networkError: return "Network connection failed"
        case .creationFailed: return "Failed to create sharing request"
        case .fetchFailed: return "Failed to fetch sharing requests"
        case .invalidResponse: return "Invalid response from server"
        case .updateFailed: return "Failed to update sharing request"
        case .invalidRequest: return "Invalid request"
        }
    }
}
