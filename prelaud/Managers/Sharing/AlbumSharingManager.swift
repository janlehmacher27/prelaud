//
//  AlbumSharingManager.swift - COMPLETE FIXED VERSION
//  prelaud
//
//  FIXED: PocketBase verwendet eigene ID-Formate, nicht UUIDs
//

import Foundation
import SwiftUI

@MainActor
class AlbumSharingManager: ObservableObject {
    static let shared = AlbumSharingManager()
    
    @Published var sharedWithMeAlbums: [Album] = []
    @Published var pendingSharingRequests: [SharingRequest] = []
    @Published var isLoadingSharedAlbums = false
    @Published var isLoadingRequests = false
    @Published var sharingError: String?
    
    private let pocketBase = PocketBaseManager.shared
    private let logger = RemoteLogger.shared
    
    private init() {
        Task {
            _ = await loadSharedAlbums()
            _ = await loadPendingRequests()
        }
        setupDeleteNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Delete Notifications Setup
    
    func setupDeleteNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AlbumDeleted"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let shareId = notification.userInfo?["shareId"] as? String {
                Task { @MainActor in
                    self?.handleAlbumDeleted(shareId: shareId)
                }
            }
        }
    }
    
    // MARK: - Core Sharing Function (ENHANCED)
    
    func createSharingRequest(_ album: Album, targetUsername: String, permissions: SharePermissions) async throws -> String {
        logger.info("🔗 Creating sharing request for album: \(album.title) to user: @\(targetUsername)")
        
        // 1. Get current user and validate
        guard let currentUser = UserProfileManager.shared.userProfile,
              let cloudId = currentUser.cloudId else {
            logger.error("❌ Current user not properly configured")
            throw SharingError.userNotValid
        }
        
        logger.info("📤 Sharing from: @\(currentUser.username) (cloudId: \(cloudId))")
        
        // 2. Look up target user by username
        logger.info("🔍 Looking up target user: @\(targetUsername)")
        
        let encodedUsername = targetUsername.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? targetUsername
        let userSearchURL = URL(string: "\(pocketBase.baseURL)/api/collections/users/records?filter=username='\(encodedUsername)'")!
        let userRequest = pocketBase.createRequest(url: userSearchURL)
        
        let (userData, userResponse) = try await pocketBase.urlSession.data(for: userRequest)
        
        guard let httpUserResponse = userResponse as? HTTPURLResponse else {
            throw SharingError.networkError
        }
        
        if httpUserResponse.statusCode != 200 {
            logger.error("❌ Failed to search for user: \(httpUserResponse.statusCode)")
            throw SharingError.userNotFound
        }
        
        guard let userJson = try JSONSerialization.jsonObject(with: userData) as? [String: Any],
              let userItems = userJson["items"] as? [[String: Any]],
              let targetUser = userItems.first,
              let targetUserId = targetUser["id"] as? String else {
            logger.error("❌ Target user not found: @\(targetUsername)")
            throw SharingError.userNotFound
        }
        
        logger.success("✅ Found target user: \(targetUserId)")
        
        // 3. Generate shareId and prepare album data
        let shareId = generateShareId()
        let currentDate = ISO8601DateFormatter().string(from: Date())
        
        // FIXED: Store album data BEFORE creating the request, with enhanced error handling
        let encodableAlbum = EncodableAlbum(
            from: album,
            shareId: shareId,
            ownerId: cloudId,
            ownerUsername: currentUser.username
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let albumData = try encoder.encode(encodableAlbum)
            UserDefaults.standard.set(albumData, forKey: "SharedAlbumData_\(shareId)")
            logger.success("✅ Album data stored locally for shareId: \(shareId)")
            
            // FIXED: Verify the storage immediately
            if let storedData = UserDefaults.standard.data(forKey: "SharedAlbumData_\(shareId)") {
                logger.info("✅ Verified album data storage: \(storedData.count) bytes")
            } else {
                logger.error("❌ Failed to verify album data storage")
                throw SharingError.creationFailed
            }
        } catch {
            logger.error("❌ Failed to encode album data: \(error)")
            throw SharingError.creationFailed
        }
        
        // 4. Create sharing request
        let requestData: [String: Any] = [
            "share_id": shareId,
            "album_id": album.id.uuidString,
            "album_title": album.title,
            "album_artist": album.artist,
            "from_user_id": cloudId,
            "from_username": currentUser.username,
            "to_user_id": targetUserId,
            "to_username": targetUsername,
            "song_count": album.songs.count,
            "can_listen": permissions.canListen,
            "can_download": permissions.canDownload,
            "expires_at": permissions.expiresAt?.ISO8601Format() ?? "",
            "status": "pending",
            "is_read": false,
            "created_at": currentDate,
            "permissions": createPermissionsDict(permissions)
        ]
        
        logger.info("📋 Request data prepared for: \(shareId)")
        
        let requestURL = URL(string: "\(pocketBase.baseURL)/api/collections/sharing_requests/records")!
        var request = pocketBase.createRequest(url: requestURL, method: "POST")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestData)
        
        let (responseData, response) = try await pocketBase.urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            // Clean up stored data on failure
            UserDefaults.standard.removeObject(forKey: "SharedAlbumData_\(shareId)")
            throw SharingError.networkError
        }
        
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            logger.success("✅ Sharing request created successfully: \(shareId)")
            return shareId
        } else {
            // Clean up stored data on failure
            UserDefaults.standard.removeObject(forKey: "SharedAlbumData_\(shareId)")
            let errorMessage = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            logger.error("❌ Failed to create sharing request: \(httpResponse.statusCode) - \(errorMessage)")
            throw SharingError.creationFailed
        }
    }
    
    // MARK: - Helper Functions
    
    private func createPermissionsDict(_ permissions: SharePermissions) -> [String: Any] {
        var permissionsDict: [String: Any] = [
            "can_listen": permissions.canListen,
            "can_download": permissions.canDownload
        ]
        
        if let expiresAt = permissions.expiresAt {
            permissionsDict["expires_at"] = expiresAt.ISO8601Format()
        } else {
            permissionsDict["expires_at"] = NSNull()
        }
        
        return permissionsDict
    }
    
    // FIXED: Complete respondToRequest function
    func respondToRequest(requestId: String, accept: Bool) async throws {
        let status = accept ? "accepted" : "declined"
        logger.info("📝 Responding to PocketBase request \(requestId): \(status)")
        
        // FIXED: Find the request BEFORE we modify anything
        guard let sharingRequest = pendingSharingRequests.first(where: { $0.pocketBaseId == requestId }) else {
            logger.error("❌ Sharing request not found: \(requestId)")
            throw SharingError.invalidResponse
        }
        
        let updateData: [String: Any] = [
            "status": status,
            "is_read": true
        ]
        
        let url = URL(string: "\(pocketBase.baseURL)/api/collections/sharing_requests/records/\(requestId)")!
        var request = pocketBase.createRequest(url: url, method: "PATCH")
        request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
        
        let (responseData, response) = try await pocketBase.urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SharingError.networkError
        }
        
        if httpResponse.statusCode == 200 {
            logger.success("✅ Request response recorded: \(status)")
            
            // FIXED: Remove from pending requests using PocketBase ID
            pendingSharingRequests.removeAll { $0.pocketBaseId == requestId }
            
            if accept {
                // FIXED: Add album to shared albums when accepted
                try await handleAcceptedRequest(sharingRequest)
                
                // FIXED: Update the albums database with shared_with info
                try await updateAlbumSharedWith(albumId: sharingRequest.albumId,
                                              userId: sharingRequest.toUserId)
            }
            
        } else {
            let errorMessage = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            logger.error("❌ Failed to respond to request: \(httpResponse.statusCode) - \(errorMessage)")
            throw SharingError.updateFailed
        }
    }
    
    // FIXED: New helper function to handle accepted requests
    private func handleAcceptedRequest(_ sharingRequest: SharingRequest) async throws {
        logger.info("✅ Processing accepted sharing request: \(sharingRequest.shareId)")
        
        // Check if album data is already stored
        if let albumData = UserDefaults.standard.data(forKey: "SharedAlbumData_\(sharingRequest.shareId)") {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let encodableAlbum = try decoder.decode(EncodableAlbum.self, from: albumData)
                let album = encodableAlbum.toAlbum()
                
                // Add to shared albums if not already present
                if !sharedWithMeAlbums.contains(where: { $0.shareId == sharingRequest.shareId }) {
                    sharedWithMeAlbums.append(album)
                    logger.success("✅ Added shared album to local list: \(album.title)")
                }
            } catch {
                logger.error("❌ Failed to decode shared album: \(error)")
                throw SharingError.invalidResponse
            }
        } else {
            // If album data is not found, fetch it from the original sharing request
            logger.warning("⚠️ Album data not found for shareId: \(sharingRequest.shareId)")
            // You might want to fetch the full album data here if needed
        }
    }
    
    // FIXED: New function to update albums database with shared_with info
    private func updateAlbumSharedWith(albumId: UUID, userId: String) async throws {
        logger.info("📝 Updating album shared_with field: \(albumId) for user: \(userId)")
        
        // First, get the current album to read existing shared_with
        let albumURL = URL(string: "\(pocketBase.baseURL)/api/collections/albums/records?filter=album_id=\"\(albumId)\"")!
        let getRequest = pocketBase.createRequest(url: albumURL)
        
        let (getData, getResponse) = try await pocketBase.urlSession.data(for: getRequest)
        
        guard let httpGetResponse = getResponse as? HTTPURLResponse else {
            throw SharingError.networkError
        }
        
        if httpGetResponse.statusCode == 200 {
            guard let jsonObject = try JSONSerialization.jsonObject(with: getData) as? [String: Any],
                  let items = jsonObject["items"] as? [[String: Any]],
                  let albumRecord = items.first,
                  let recordId = albumRecord["id"] as? String else {
                logger.warning("⚠️ Album not found in database: \(albumId)")
                return
            }
            
            // Get existing shared_with array
            var sharedWith = albumRecord["shared_with"] as? [String] ?? []
            
            // Add userId if not already present
            if !sharedWith.contains(userId) {
                sharedWith.append(userId)
                
                // Update the album record
                let updateData: [String: Any] = [
                    "shared_with": sharedWith
                ]
                
                let updateURL = URL(string: "\(pocketBase.baseURL)/api/collections/albums/records/\(recordId)")!
                var updateRequest = pocketBase.createRequest(url: updateURL, method: "PATCH")
                updateRequest.httpBody = try JSONSerialization.data(withJSONObject: updateData)
                
                let (updateResponseData, updateResponse) = try await pocketBase.urlSession.data(for: updateRequest)
                
                guard let httpUpdateResponse = updateResponse as? HTTPURLResponse else {
                    throw SharingError.networkError
                }
                
                if httpUpdateResponse.statusCode == 200 {
                    logger.success("✅ Updated album shared_with field successfully")
                } else {
                    let errorMessage = String(data: updateResponseData, encoding: .utf8) ?? "Unknown error"
                    logger.error("❌ Failed to update album shared_with: \(httpUpdateResponse.statusCode) - \(errorMessage)")
                }
            } else {
                logger.info("ℹ️ User already in shared_with list")
            }
        } else {
            let errorMessage = String(data: getData, encoding: .utf8) ?? "Unknown error"
            logger.warning("⚠️ Could not find album in database: \(httpGetResponse.statusCode) - \(errorMessage)")
        }
    }
    
    // MARK: - Load Functions (ENHANCED)
    
    func loadSharedAlbums() async -> [Album] {
        isLoadingSharedAlbums = true
        sharingError = nil
        
        defer {
            Task { @MainActor in
                self.isLoadingSharedAlbums = false
            }
        }
        
        logger.info("📂 Loading shared albums from local storage")
        
        var albums: [Album] = []
        
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix("SharedAlbumData_") {
                if let data = defaults.data(forKey: key) {
                    do {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        let encodableAlbum = try decoder.decode(EncodableAlbum.self, from: data)
                        let album = encodableAlbum.toAlbum()
                        albums.append(album)
                        logger.database("📂 Loaded shared album: \(album.title)")
                    } catch {
                        logger.warning("⚠️ Failed to decode shared album from key: \(key) - \(error)")
                    }
                }
            }
        }
        
        await MainActor.run {
            self.sharedWithMeAlbums = albums
        }
        logger.success("✅ Loaded \(albums.count) shared albums")
        return albums
    }
    
    // FIXED: loadPendingRequests function with better filtering
    func loadPendingRequests() async -> [SharingRequest]? {
        isLoadingRequests = true
        sharingError = nil
        
        defer {
            Task { @MainActor in
                self.isLoadingRequests = false
            }
        }
        
        do {
            guard let currentUser = UserProfileManager.shared.userProfile,
                  let userCloudId = currentUser.cloudId else {
                logger.error("❌ No user profile for loading requests")
                return nil
            }
            
            // FIXED: Query only for pending requests explicitly
            let url = URL(string: "\(pocketBase.baseURL)/api/collections/sharing_requests/records?filter=to_user_id=\"\(userCloudId)\"&&status=\"pending\"")!
            logger.info("🔍 Loading pending requests for to_user_id=\(userCloudId)")
            let request = pocketBase.createRequest(url: url)
            
            let (data, response) = try await pocketBase.urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SharingError.networkError
            }
            
            logger.info("📋 Load requests response: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                logger.info("📄 Complete response: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                let requests = try parseSharingRequests(from: data)
                
                // FIXED: Double-check that we only return pending requests
                let pendingOnly = requests.filter { $0.status == .pending }
                
                await MainActor.run {
                    self.pendingSharingRequests = pendingOnly
                }
                logger.success("✅ Loaded \(pendingOnly.count) pending sharing requests")
                return pendingOnly
            } else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("❌ Failed to load requests: \(httpResponse.statusCode) - \(errorMessage)")
                await MainActor.run {
                    self.sharingError = "Failed to load sharing requests"
                }
                return nil
            }
            
        } catch {
            logger.error("❌ Error loading sharing requests: \(error)")
            await MainActor.run {
                self.sharingError = "Failed to load sharing requests: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    // MARK: - Parser für PocketBase IDs
    
    private func parseSharingRequests(from data: Data) throws -> [SharingRequest] {
        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = jsonObject["items"] as? [[String: Any]] else {
            throw SharingError.invalidResponse
        }
        
        logger.info("🔍 Parsing \(items.count) sharing requests from PocketBase")
        
        return try items.compactMap { item in
            try parseSharingRequest(from: item)
        }
    }
    
    // FIXED: Date parsing in parseSharingRequest function
    private func parseSharingRequest(from item: [String: Any]) throws -> SharingRequest? {
        logger.info("🔍 Parsing sharing request with keys: \(item.keys.joined(separator: ", "))")
        
        // FIXED: PocketBase ID ist kein UUID!
        guard let pocketBaseId = item["id"] as? String,
              let shareId = item["share_id"] as? String,
              let albumIdString = item["album_id"] as? String,
              let albumTitle = item["album_title"] as? String,
              let fromUserId = item["from_user_id"] as? String,
              let fromUsername = item["from_username"] as? String,
              let toUserId = item["to_user_id"] as? String,
              let albumArtist = item["album_artist"] as? String,
              let createdAtString = item["created_at"] as? String else {
            logger.warning("⚠️ Missing required fields in sharing request")
            return nil
        }
        
        // Parse UUID for albumId
        guard let albumId = UUID(uuidString: albumIdString) else {
            logger.warning("⚠️ Invalid album UUID: \(albumIdString)")
            return nil
        }
        
        // FIXED: Parse date with multiple formatters for PocketBase format
        let createdAt: Date
        if let parsedDate = parsePocketBaseDate(createdAtString) {
            createdAt = parsedDate
        } else {
            logger.warning("⚠️ Invalid date format: \(createdAtString) - using current date")
            createdAt = Date()
        }
        
        // Parse optional fields
        let songCount = item["song_count"] as? Int ?? 0
        let isRead = item["is_read"] as? Bool ?? false
        
        // Parse permissions
        let permissions: SharePermissions
        if let permissionsDict = item["permissions"] as? [String: Any] {
            permissions = SharePermissions(
                canListen: permissionsDict["can_listen"] as? Bool ?? true,
                canDownload: permissionsDict["can_download"] as? Bool ?? false,
                expiresAt: nil
            )
        } else {
            permissions = SharePermissions(
                canListen: item["can_listen"] as? Bool ?? true,
                canDownload: item["can_download"] as? Bool ?? false,
                expiresAt: nil
            )
        }
        
        let statusString = item["status"] as? String ?? "pending"
        let requestStatus = SharingRequestStatus(rawValue: statusString) ?? .pending
        
        // FIXED: Verwende eine generierte UUID für id, aber speichere PocketBase ID separat
        let request = SharingRequest(
            id: UUID(), // Generiere neue UUID für lokale Verwendung
            pocketBaseId: pocketBaseId, // Speichere PocketBase ID separat
            shareId: shareId,
            fromUserId: fromUserId,
            fromUsername: fromUsername,
            toUserId: toUserId,
            albumId: albumId,
            albumTitle: albumTitle,
            albumArtist: albumArtist,
            songCount: songCount,
            permissions: permissions,
            createdAt: createdAt,
            isRead: isRead,
            status: requestStatus
        )
        
        logger.success("✅ Parsed sharing request: \(shareId) from @\(fromUsername) (PocketBase ID: \(pocketBaseId))")
        return request
    }

    // FIXED: Add helper function to parse PocketBase dates
    private func parsePocketBaseDate(_ dateString: String) -> Date? {
        // PocketBase format: "2025-07-24 16:07:05.000Z"
        let pocketBaseFormatter = DateFormatter()
        pocketBaseFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSZ"
        pocketBaseFormatter.timeZone = TimeZone(abbreviation: "UTC")
        
        if let date = pocketBaseFormatter.date(from: dateString) {
            return date
        }
        
        // Fallback: ISO8601 formatter
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        // Second fallback: Basic ISO8601
        let basicISO8601 = ISO8601DateFormatter()
        return basicISO8601.date(from: dateString)
    }
    
    private func handleAlbumDeleted(shareId: String) {
        logger.info("📢 Handling album deletion for shareId: \(shareId)")
        
        sharedWithMeAlbums.removeAll { $0.shareId == shareId }
        UserDefaults.standard.removeObject(forKey: "SharedAlbumData_\(shareId)")
        
        logger.success("✅ Cleaned up deleted shared album")
    }
    
    private func generateShareId() -> String {
        return "share_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(12))"
    }
    
    // MARK: - Public Interface
    
    func refreshAll() {
        Task {
            _ = await loadPendingRequests()
            _ = await loadSharedAlbums()
        }
    }
    
    func removeSharedAlbum(shareId: String) async throws {
        logger.info("🗑️ Removing shared album: \(shareId)")
        
        UserDefaults.standard.removeObject(forKey: "SharedAlbumData_\(shareId)")
        sharedWithMeAlbums.removeAll { $0.shareId == shareId }
        
        logger.success("✅ Shared album removed")
    }
    
    func getSharedAlbumCount() -> Int {
        return sharedWithMeAlbums.count
    }
    
    func getPendingRequestsCount() -> Int {
        return pendingSharingRequests.count
    }
}
