//
//  AlbumSharingManager.swift - CLEAN VERSION
//  prelaud
//
//  Uses central SharingModels.swift - no duplicate definitions
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
        loadSharedAlbums()
        Task {
            await loadPendingSharingRequests()
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
                self?.handleAlbumDeleted(shareId: shareId)
            }
        }
    }
    
    // MARK: - Core Sharing Functions
    
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
            logger.error("❌ User lookup failed: \(httpUserResponse.statusCode)")
            throw SharingError.userNotFound
        }
        
        // Parse user lookup response
        guard let userJsonArray = try JSONSerialization.jsonObject(with: userData) as? [[String: Any]],
              let userDict = userJsonArray.first,
              let userIdString = userDict["id"] as? String else {
            logger.error("❌ User not found or invalid user data")
            throw SharingError.userNotFound
        }
        
        logger.success("✅ Found target user with ID: \(userIdString)")
        
        // 3. Create sharing request with proper date formatting
        let shareId = generateShareId()
        logger.info("🔍 Generated share ID: \(shareId)")
        
        // Create permissions as JSON string
        let permissionsJson: [String: Any] = [
            "can_listen": permissions.canListen,
            "can_download": permissions.canDownload,
            "expires_at": permissions.expiresAt?.iso8601String as Any
        ]
        
        let permissionsJsonData = try JSONSerialization.data(withJSONObject: permissionsJson)
        let permissionsJsonString = String(data: permissionsJsonData, encoding: .utf8) ?? "{}"
        
        // 4. Create sharing request data
        let sharingRequestData: [String: Any] = [
            "share_id": shareId,
            "from_user_id": currentUser.cloudId!,
            "from_username": currentUser.username,
            "to_user_id": userIdString,
            "album_id": album.id.uuidString,
            "album_title": album.title,
            "album_artist": album.artist,
            "song_count": album.songs.count,
            "permissions": permissionsJsonString,
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "is_read": false,
            "status": "pending"
        ]
        
        logger.database("🔍 Sharing request data prepared")
        
        // 5. Store album data for sharing
        let albumData = EncodableAlbum(
            from: album,
            shareId: shareId,
            ownerId: currentUser.cloudId!,
            ownerUsername: currentUser.username
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let encoded = try? encoder.encode(albumData) {
            UserDefaults.standard.set(encoded, forKey: "SharedAlbumData_\(shareId)")
            logger.success("✅ Album data stored locally")
        }
        
        // 6. Send to PocketBase
        let sharingURL = URL(string: "\(pocketBase.baseURL)/api/collections/sharing_requests/records")!
        var request = pocketBase.createRequest(url: sharingURL, method: "POST")
        request.httpBody = try JSONSerialization.data(withJSONObject: sharingRequestData)
        
        let (responseData, response) = try await pocketBase.urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("❌ Invalid response type")
            throw SharingError.networkError
        }
        
        logger.info("📋 Sharing request response: \(httpResponse.statusCode)")
        
        if let responseString = String(data: responseData, encoding: .utf8) {
            logger.debug("📄 Response: \(responseString)")
        }
        
        if (200...299).contains(httpResponse.statusCode) {
            logger.success("✅ Sharing request created successfully")
            
            // Refresh pending requests
            await loadPendingSharingRequests()
            
            return shareId
        } else {
            let errorMessage = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            logger.error("❌ Sharing request failed: \(httpResponse.statusCode) - \(errorMessage)")
            throw SharingError.creationFailed
        }
    }
    
    // MARK: - Load Pending Sharing Requests
    
    func loadPendingSharingRequests() async {
        guard let currentUser = UserProfileManager.shared.userProfile,
              let cloudId = currentUser.cloudId else {
            logger.warning("⚠️ No user profile - cannot load sharing requests")
            return
        }
        
        isLoadingRequests = true
        logger.info("🔍 Loading pending sharing requests for @\(currentUser.username)")
        
        do {
            let endpoint = "\(pocketBase.baseURL)/api/collections/sharing_requests/records?filter=to_user_id='\(cloudId)'&&status='pending'&sort=-created_at"
            guard let url = URL(string: endpoint) else {
                throw SharingError.invalidRequest
            }
            
            let request = pocketBase.createRequest(url: url)
            let (data, response) = try await pocketBase.urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SharingError.networkError
            }
            
            logger.info("📋 Load requests response: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                let requests = try parseSharingRequests(from: data)
                
                await MainActor.run {
                    pendingSharingRequests = requests
                    logger.success("✅ Loaded \(requests.count) pending sharing requests")
                }
            } else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("❌ Failed to load requests: \(httpResponse.statusCode) - \(errorMessage)")
            }
            
        } catch {
            logger.error("❌ Error loading sharing requests: \(error)")
            await MainActor.run {
                sharingError = "Failed to load sharing requests: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isLoadingRequests = false
        }
    }
    
    // MARK: - Accept/Decline Sharing Requests
    
    func acceptSharingRequest(_ request: SharingRequest) async throws {
        logger.info("✅ Accepting sharing request: \(request.shareId)")
        
        try await updateSharingRequestStatus(request.id.uuidString, status: "accepted")
        
        // Load the shared album data
        if let albumData = UserDefaults.standard.data(forKey: "SharedAlbumData_\(request.shareId)") {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let encodableAlbum = try decoder.decode(EncodableAlbum.self, from: albumData)
                let album = encodableAlbum.toAlbum()
                
                await MainActor.run {
                    sharedWithMeAlbums.append(album)
                    pendingSharingRequests.removeAll { $0.id == request.id }
                }
                
                logger.success("✅ Shared album added to collection: \(album.title)")
                
            } catch {
                logger.error("❌ Failed to decode shared album data: \(error)")
            }
        }
    }
    
    func declineSharingRequest(_ request: SharingRequest) async throws {
        logger.info("❌ Declining sharing request: \(request.shareId)")
        
        try await updateSharingRequestStatus(request.id.uuidString, status: "declined")
        
        await MainActor.run {
            pendingSharingRequests.removeAll { $0.id == request.id }
        }
        
        // Clean up stored album data
        UserDefaults.standard.removeObject(forKey: "SharedAlbumData_\(request.shareId)")
        
        logger.success("✅ Sharing request declined and cleaned up")
    }
    
    private func updateSharingRequestStatus(_ requestId: String, status: String) async throws {
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
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            logger.error("❌ Failed to update request status: \(httpResponse.statusCode) - \(errorMessage)")
            throw SharingError.updateFailed
        }
    }
    
    // MARK: - Load Shared Albums
    
    func loadSharedAlbums() {
        guard UserProfileManager.shared.userProfile != nil else {
            logger.warning("⚠️ No user profile - cannot load shared albums")
            return
        }
        
        Task {
            await MainActor.run {
                isLoadingSharedAlbums = true
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
                sharedWithMeAlbums = albums
                isLoadingSharedAlbums = false
                sharingError = nil
                logger.success("✅ Loaded \(albums.count) shared albums")
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func generateShareId() -> String {
        return "share_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(12))"
    }
    
    private func parseSharingRequests(from data: Data) throws -> [SharingRequest] {
        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = jsonObject["items"] as? [[String: Any]] ?? jsonObject as? [[String: Any]] else {
            throw SharingError.invalidResponse
        }
        
        var requests: [SharingRequest] = []
        
        for item in items {
            do {
                let request = try parseSingleSharingRequest(from: item)
                requests.append(request)
            } catch {
                logger.warning("⚠️ Failed to parse sharing request: \(error)")
            }
        }
        
        return requests
    }
    
    private func parseSingleSharingRequest(from dict: [String: Any]) throws -> SharingRequest {
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let shareId = dict["share_id"] as? String,
              let fromUserId = dict["from_user_id"] as? String,
              let fromUsername = dict["from_username"] as? String,
              let toUserId = dict["to_user_id"] as? String,
              let albumId = dict["album_id"] as? String,
              let albumTitle = dict["album_title"] as? String,
              let albumArtist = dict["album_artist"] as? String,
              let songCount = dict["song_count"] as? Int,
              let status = dict["status"] as? String,
              let isRead = dict["is_read"] as? Bool,
              let createdAtString = dict["created_at"] as? String else {
            throw SharingError.invalidResponse
        }
        
        let createdAt = ISO8601DateFormatter().date(from: createdAtString) ?? Date()
        
        // Parse permissions
        var permissions = SharePermissions(canListen: true, canDownload: false, expiresAt: nil)
        if let permissionsString = dict["permissions"] as? String,
           let permissionsData = permissionsString.data(using: .utf8),
           let permissionsJson = try? JSONSerialization.jsonObject(with: permissionsData) as? [String: Any] {
            
            permissions = SharePermissions(
                canListen: permissionsJson["can_listen"] as? Bool ?? true,
                canDownload: permissionsJson["can_download"] as? Bool ?? false,
                expiresAt: {
                    if let expiresAtString = permissionsJson["expires_at"] as? String {
                        return ISO8601DateFormatter().date(from: expiresAtString)
                    }
                    return nil
                }()
            )
        }
        
        return SharingRequest(
            id: id,
            shareId: shareId,
            fromUserId: fromUserId,
            fromUsername: fromUsername,
            toUserId: toUserId,
            albumId: albumId,
            albumTitle: albumTitle,
            albumArtist: albumArtist,
            songCount: songCount,
            permissions: permissions,
            status: SharingRequestStatus(rawValue: status) ?? .pending,
            isRead: isRead,
            createdAt: createdAt
        )
    }
    
    private func handleAlbumDeleted(shareId: String) {
        logger.info("📢 Handling album deletion for shareId: \(shareId)")
        
        sharedWithMeAlbums.removeAll { $0.shareId == shareId }
        UserDefaults.standard.removeObject(forKey: "SharedAlbumData_\(shareId)")
        
        logger.success("✅ Cleaned up deleted shared album")
    }
    
    // MARK: - Public Interface
    
    func refreshAll() {
        Task {
            await loadPendingSharingRequests()
            loadSharedAlbums()
        }
    }
    
    func removeSharedAlbum(shareId: String) async throws {
        logger.info("🗑️ Removing shared album: \(shareId)")
        
        UserDefaults.standard.removeObject(forKey: "SharedAlbumData_\(shareId)")
        
        await MainActor.run {
            sharedWithMeAlbums.removeAll { $0.shareId == shareId }
        }
        
        logger.success("✅ Shared album removed")
    }
    
    func getSharedAlbumCount() -> Int {
        return sharedWithMeAlbums.count
    }
    
    func getPendingRequestsCount() -> Int {
        return pendingSharingRequests.count
    }
}
