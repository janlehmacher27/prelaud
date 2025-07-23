//
//  PocketBaseSharingManager.swift - MINIMAL CLEAN VERSION
//  prelaud
//
//  Removed duplicate function definitions to avoid conflicts
//

import Foundation

// MARK: - Sharing Request Creation (Main Function Only)

func createSharingRequest(
    album: Album,
    targetUsername: String,
    permissions: SharePermissions
) async throws {
    print("🔗 Creating sharing request for album: \(album.title) to user: @\(targetUsername)")
    
    // 1. Get current user and validate
    guard let currentUser = await UserProfileManager.shared.userProfile,
          let cloudId = currentUser.cloudId else {
        print("❌ Current user not properly configured")
        throw ShareError.userNotValid
    }
    
    print("📤 Sharing from: @\(currentUser.username) (cloudId: \(cloudId))")
    
    // 2. Look up target user by username
    print("🔍 Looking up target user: @\(targetUsername)")
    
    let pocketBase = await PocketBaseManager.shared
    let encodedUsername = targetUsername.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? targetUsername
    let userSearchURL = URL(string: "\(pocketBase.baseURL)/api/collections/users/records?filter=username='\(encodedUsername)'")!
    let userRequest = await pocketBase.createRequest(url: userSearchURL)
    
    let (userData, userResponse) = try await pocketBase.urlSession.data(for: userRequest)
    
    guard let httpUserResponse = userResponse as? HTTPURLResponse else {
        throw ShareError.networkError
    }
    
    if httpUserResponse.statusCode != 200 {
        print("❌ User lookup failed: \(httpUserResponse.statusCode)")
        throw ShareError.userNotFound
    }
    
    // Parse user lookup response
    guard let userJsonArray = try JSONSerialization.jsonObject(with: userData) as? [[String: Any]],
          let userDict = userJsonArray.first,
          let userIdString = userDict["id"] as? String,
          let targetUserId = UUID(uuidString: userIdString) else {
        print("❌ User not found or invalid user data")
        throw ShareError.userNotFound
    }
    
    print("✅ Found target user with ID: \(targetUserId)")
    
    // 3. Create sharing request with proper date formatting
    let shareId = generateShareId()
    print("🔍 Generated share ID: \(shareId)")
    
    // Create permissions as JSON string
    let permissionsJson: [String: Any] = [
        "can_listen": permissions.canListen,
        "can_download": permissions.canDownload,
        "expires_at": permissions.expiresAt?.ISO8601Format() as Any
    ]
    
    let permissionsJsonData = try JSONSerialization.data(withJSONObject: permissionsJson)
    let permissionsJsonString = String(data: permissionsJsonData, encoding: .utf8) ?? "{}"
    
    // Create sharing request data
    let sharingRequestData: [String: Any] = [
        "id": UUID().uuidString,
        "share_id": shareId,
        "from_user_id": currentUser.id.uuidString,
        "from_username": currentUser.username,
        "to_user_id": targetUserId.uuidString,
        "album_id": album.id.uuidString,
        "album_title": album.title,
        "album_artist": album.artist,
        "song_count": album.songs.count,
        "permissions": permissionsJsonString,
        "created": ISO8601DateFormatter().string(from: Date()),
        "is_read": false,
        "status": "pending"
    ]
    
    // 4. Store album data for sharing
    let albumData = EncodableAlbum(
        from: album,
        shareId: shareId,
        ownerId: currentUser.id.uuidString,
        ownerUsername: currentUser.username
    )
    
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    
    if let encoded = try? encoder.encode(albumData) {
        UserDefaults.standard.set(encoded, forKey: "SharedAlbumData_\(shareId)")
        print("✅ Album data stored locally")
    }
    
    // 5. Send sharing request to PocketBase
    let sharingURL = URL(string: "\(pocketBase.baseURL)/api/collections/sharing_requests/records")!
    var sharingRequest = await pocketBase.createRequest(url: sharingURL, method: "POST")
    sharingRequest.httpBody = try JSONSerialization.data(withJSONObject: sharingRequestData)
    
    let (responseData, response) = try await pocketBase.urlSession.data(for: sharingRequest)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw ShareError.networkError
    }
    
    if httpResponse.statusCode == 200 {
        print("✅ Sharing request created successfully")
        if let responseString = String(data: responseData, encoding: .utf8) {
            print("📋 Response: \(responseString)")
        }
    } else {
        let errorMessage = String(data: responseData, encoding: .utf8) ?? "Unknown error"
        print("❌ Failed to create sharing request: \(httpResponse.statusCode) - \(errorMessage)")
        throw ShareError.requestFailed
    }
}

// MARK: - Utility Functions

private func generateShareId() -> String {
    return UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(8).description
}

// MARK: - Simplified Sharing Errors (Renamed to avoid conflicts)

enum ShareError: Error, LocalizedError {
    case userNotValid
    case userNotFound
    case networkError
    case requestFailed
    case fetchFailed
    case parsingFailed
    case updateFailed
    
    var errorDescription: String? {
        switch self {
        case .userNotValid: return "Current user is not properly configured"
        case .userNotFound: return "Target user not found"
        case .networkError: return "Network connection failed"
        case .requestFailed: return "Failed to create sharing request"
        case .fetchFailed: return "Failed to fetch sharing requests"
        case .parsingFailed: return "Failed to parse sharing data"
        case .updateFailed: return "Failed to update sharing request"
        }
    }
}
