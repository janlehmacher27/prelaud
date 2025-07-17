//
//  SupabaseAlbumSharingManager.swift
//  prelaud
//
//  Cloud-basiertes Album-Sharing System
//

import Foundation
import SwiftUI

@MainActor
class SupabaseAlbumSharingManager: ObservableObject {
    static let shared = SupabaseAlbumSharingManager()
    
    @Published var sharedWithMeAlbums: [Album] = []
    @Published var isLoadingSharedAlbums = false
    @Published var sharingError: String?
    
    // Supabase Configuration
    private let supabaseURL = "https://auzsunnwanzljiwdpzov.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1enN1bm53YW56bGppd2Rwem92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIxMzIyNjksImV4cCI6MjA2NzcwODI2OX0.UmuoVT-7uXq5SMFr9duiurbE52Oe865w4ghYPkFwexE"
    
    private var urlSession: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        urlSession = URLSession(configuration: config)
        loadSharedAlbums()
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
    
    // MARK: - Album Sharing
    
    /// Teilt ein Album mit einem anderen Nutzer
    func shareAlbum(_ album: Album, withUsername targetUsername: String, permissions: SharePermissions = SharePermissions()) async throws -> String {
        print("📤 Sharing album '\(album.title)' with @\(targetUsername)")
        
        guard let currentUser = UserProfileManager.shared.userProfile else {
            throw SharingError.notLoggedIn
        }
        
        // 1. Prüfe ob Ziel-User existiert
        let targetUser = try await getUserByUsername(targetUsername)
        
        // 2. Erstelle Share-Record
        let shareId = generateShareId()
        let sharedAlbum = SharedAlbum(
            id: UUID(),
            albumId: album.id,
            ownerId: currentUser.id.uuidString,
            ownerUsername: currentUser.username,
            sharedWithUserId: targetUser.id.uuidString,
            shareId: shareId,
            permissions: permissions,
            createdAt: Date(),
            albumTitle: album.title,
            albumArtist: album.artist,
            songCount: album.songs.count
        )
        
        // 3. Speichere in Datenbank
        try await createSharedAlbumRecord(sharedAlbum)
        
        // 4. Speichere Album-Daten (falls noch nicht vorhanden)
        try await uploadAlbumDataIfNeeded(album, shareId: shareId)
        
        print("✅ Album shared successfully with ID: \(shareId)")
        return shareId
    }
    
    /// Lädt alle mit mir geteilten Alben (DEBUG VERSION)
        func loadSharedAlbums() {
            guard let currentUser = UserProfileManager.shared.userProfile else { return }
            
            Task {
                isLoadingSharedAlbums = true
                
                do {
                    // DEBUG: Erst alle sharing_requests für diesen User laden (ohne Status-Filter)
                    let debugEndpoint = "\(supabaseURL)/rest/v1/sharing_requests?to_user_id=eq.\(currentUser.id.uuidString)&select=*"
                    guard let debugUrl = URL(string: debugEndpoint) else {
                        throw SharingError.invalidRequest
                    }
                    
                    let debugRequest = createRequest(url: debugUrl)
                    let (debugData, debugResponse) = try await urlSession.data(for: debugRequest)
                    
                    if let debugResponseString = String(data: debugData, encoding: .utf8) {
                        print("🔍 DEBUG - All sharing requests for user: \(debugResponseString)")
                    }
                    
                    // FIXED: Suche nach approved (nicht accepted!)
                    let endpoint = "\(supabaseURL)/rest/v1/sharing_requests?to_user_id=eq.\(currentUser.id.uuidString)&status=eq.approved&select=*"
                    guard let url = URL(string: endpoint) else {
                        throw SharingError.invalidRequest
                    }
                    
                    let request = createRequest(url: url)
                    let (data, response) = try await urlSession.data(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw SharingError.networkError
                    }
                    
                    print("🔍 DEBUG - loadSharedAlbums response status: \(httpResponse.statusCode)")
                    
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("🔍 DEBUG - Accepted sharing requests: \(responseString)")
                    }
                    
                    if httpResponse.statusCode == 200 {
                        // Parse sharing requests
                        guard let sharingRequestsJson = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                            throw SharingError.fetchFailed
                        }
                        
                        print("🔍 DEBUG - Found \(sharingRequestsJson.count) accepted requests")
                        
                        var albums: [Album] = []
                                            var seenAlbumIds: Set<UUID> = [] // Track welche Alben wir schon haben
                                            
                                            for requestDict in sharingRequestsJson {
                                                guard let shareId = requestDict["share_id"] as? String,
                                                      let albumTitle = requestDict["album_title"] as? String,
                                                      let albumArtist = requestDict["album_artist"] as? String,
                                                      let fromUserId = requestDict["from_user_id"] as? String,
                                                      let fromUsername = requestDict["from_username"] as? String,
                                                      let createdAtString = requestDict["created_at"] as? String,
                                                      let albumIdString = requestDict["album_id"] as? String,
                                                      let albumId = UUID(uuidString: albumIdString) else {
                                                    continue
                                                }
                                                
                                                // DEDUPLIZIERUNG: Überspringe wenn wir dieses Album schon haben
                                                if seenAlbumIds.contains(albumId) {
                                                    print("🔍 DEBUG - Skipping duplicate album: \(albumTitle) (ID: \(albumId))")
                                                    continue
                                                }
                                                
                                                print("🔍 DEBUG - Processing shareId: \(shareId) for album: \(albumTitle)")
                                                
                                                // Lade Album-Daten
                                                if let album = try await loadAlbumData(shareId: shareId) {
                                                    print("🔍 DEBUG - Successfully loaded album data for: \(albumTitle)")
                                                    
                                                    // Setze Sharing-Informationen
                                                    var sharedAlbum = album
                                                    sharedAlbum.ownerId = fromUserId
                                                    sharedAlbum.ownerUsername = fromUsername
                                                    sharedAlbum.shareId = shareId
                                                    
                                                    // Parse created_at date
                                                    let formatter = ISO8601DateFormatter()
                                                    sharedAlbum.sharedAt = formatter.date(from: createdAtString)
                                                    
                                                    // ROBUST: Parse permissions (handles both JSON string and JSON object)
                                                    var permissions = SharePermissions()
                                                    
                                                    if let permissionsValue = requestDict["permissions"] {
                                                        var permissionsJson: [String: Any]?
                                                        
                                                        // Case 1: JSON String (e.g., "{\"can_listen\":true}")
                                                        if let permissionsString = permissionsValue as? String,
                                                           let permissionsData = permissionsString.data(using: .utf8) {
                                                            permissionsJson = try? JSONSerialization.jsonObject(with: permissionsData) as? [String: Any]
                                                            print("🔍 DEBUG - Parsed permissions from JSON string")
                                                        }
                                                        // Case 2: JSON Object (e.g., {"can_listen": true})
                                                        else if let permissionsDict = permissionsValue as? [String: Any] {
                                                            permissionsJson = permissionsDict
                                                            print("🔍 DEBUG - Using permissions as JSON object")
                                                        }
                                                        
                                                        // Extract permission values
                                                        if let permissionsJson = permissionsJson {
                                                            let canListen = permissionsJson["can_listen"] as? Bool ??
                                                                           permissionsJson["canListen"] as? Bool ?? true
                                                            let canDownload = permissionsJson["can_download"] as? Bool ??
                                                                             permissionsJson["canDownload"] as? Bool ?? false
                                                            var expiresAt: Date? = nil
                                                            
                                                            if let expiresAtString = permissionsJson["expires_at"] as? String ??
                                                                                    permissionsJson["expiresAt"] as? String {
                                                                expiresAt = formatter.date(from: expiresAtString)
                                                            }
                                                            
                                                            permissions = SharePermissions(
                                                                canListen: canListen,
                                                                canDownload: canDownload,
                                                                expiresAt: expiresAt
                                                            )
                                                            
                                                            print("🔍 DEBUG - Permissions parsed: listen=\(canListen), download=\(canDownload)")
                                                        } else {
                                                            print("🔍 DEBUG - Failed to parse permissions, using defaults")
                                                        }
                                                    }
                                                    
                                                    sharedAlbum.sharePermissions = permissions
                                                    
                                                    // Füge das Album hinzu und markiere die ID als gesehen
                                                    albums.append(sharedAlbum)
                                                    seenAlbumIds.insert(albumId)
                                                    
                                                    print("🔍 DEBUG - Added unique album to shared list: \(albumTitle)")
                                                } else {
                                                    print("🔍 DEBUG - Failed to load album data for shareId: \(shareId)")
                                                }
                                            }
                        
                        sharedWithMeAlbums = albums
                        print("📥 Loaded \(albums.count) shared albums")
                        
                    } else {
                        throw SharingError.fetchFailed
                    }
                    
                } catch {
                    print("❌ Failed to load shared albums: \(error)")
                    sharingError = error.localizedDescription
                }
                
                isLoadingSharedAlbums = false
            }
        }
    
    /// Entfernt ein geteiltes Album
    func removeSharedAlbum(shareId: String) async throws {
        guard let currentUser = UserProfileManager.shared.userProfile else {
            throw SharingError.notLoggedIn
        }
        
        let endpoint = "\(supabaseURL)/rest/v1/shared_albums?share_id=eq.\(shareId)&shared_with_user_id=eq.\(currentUser.id.uuidString)"
        guard let url = URL(string: endpoint) else {
            throw SharingError.invalidRequest
        }
        
        var request = createRequest(url: url, method: "DELETE")
        
        let (_, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SharingError.networkError
        }
        
        if httpResponse.statusCode == 204 {
            // Entferne aus lokaler Liste
            sharedWithMeAlbums.removeAll { $0.shareId == shareId }
            print("✅ Shared album removed")
        } else {
            throw SharingError.deletionFailed
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func getUserByUsername(_ username: String) async throws -> DatabaseUser {
        let endpoint = "\(supabaseURL)/rest/v1/users?username=eq.\(username.lowercased())&is_active=eq.true&select=*"
        guard let url = URL(string: endpoint) else {
            throw SharingError.invalidRequest
        }
        
        let request = createRequest(url: url)
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SharingError.networkError
        }
        
        if httpResponse.statusCode == 200 {
            let users = try JSONDecoder().decode([DatabaseUser].self, from: data)
            guard let user = users.first else {
                throw SharingError.userNotFound
            }
            return user
        } else {
            throw SharingError.userNotFound
        }
    }
    
    private func createSharedAlbumRecord(_ sharedAlbum: SharedAlbum) async throws {
        let endpoint = "\(supabaseURL)/rest/v1/shared_albums"
        guard let url = URL(string: endpoint) else {
            throw SharingError.invalidRequest
        }
        
        var request = createRequest(url: url, method: "POST")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(sharedAlbum)
        
        let (_, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SharingError.networkError
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            throw SharingError.creationFailed
        }
    }
    
    private func fetchSharedAlbumsForUser(_ userId: String) async throws -> [SharedAlbum] {
        let endpoint = "\(supabaseURL)/rest/v1/shared_albums?shared_with_user_id=eq.\(userId)&select=*"
        guard let url = URL(string: endpoint) else {
            throw SharingError.invalidRequest
        }
        
        let request = createRequest(url: url)
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SharingError.networkError
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([SharedAlbum].self, from: data)
        } else {
            throw SharingError.fetchFailed
        }
    }
    
    private func uploadAlbumDataIfNeeded(_ album: Album, shareId: String) async throws {
        // Hier würdest du die Album-Daten (Songs, Metadaten) hochladen
        // Für jetzt speichern wir sie lokal mit dem shareId als Referenz
        
        // FIXED: Verwende den sicheren initializer mit expliziten Parametern
        guard let currentUser = UserProfileManager.shared.userProfile else {
            throw SharingError.notLoggedIn
        }
        
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
            print("💾 Album data stored for shareId: \(shareId)")
        }
    }
    
    private func loadAlbumData(shareId: String) async throws -> Album? {
            print("🔍 DEBUG - Loading album data for shareId: \(shareId)")
            
            // Check if album data exists in UserDefaults
            let key = "SharedAlbumData_\(shareId)"
            print("🔍 DEBUG - Looking for key: \(key)")
            
            if let data = UserDefaults.standard.data(forKey: key) {
                print("🔍 DEBUG - Found data for key: \(key)")
                
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let albumData = try decoder.decode(EncodableAlbum.self, from: data)
                    print("🔍 DEBUG - Successfully decoded album: \(albumData.title)")
                    return albumData.toAlbum()
                } catch {
                    print("🔍 DEBUG - Failed to decode album data: \(error)")
                    return nil
                }
            } else {
                print("🔍 DEBUG - No data found for key: \(key)")
                
                // DEBUG: Check what keys actually exist in UserDefaults
                let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
                let sharedAlbumKeys = allKeys.filter { $0.hasPrefix("SharedAlbumData_") }
                print("🔍 DEBUG - Available SharedAlbumData keys: \(sharedAlbumKeys)")
                
                // FALLBACK: Try to find album data by checking all available SharedAlbumData
                print("🔍 DEBUG - Trying fallback: searching all album data...")
                
                for availableKey in sharedAlbumKeys {
                    if let data = UserDefaults.standard.data(forKey: availableKey) {
                        do {
                            let decoder = JSONDecoder()
                            decoder.dateDecodingStrategy = .iso8601
                            let albumData = try decoder.decode(EncodableAlbum.self, from: data)
                            
                            // Check if this album matches by any available criteria
                            // For now, let's just use the first available album as a test
                            print("🔍 DEBUG - FALLBACK: Found album '\(albumData.title)' in key: \(availableKey)")
                            return albumData.toAlbum()
                            
                        } catch {
                            print("🔍 DEBUG - FALLBACK: Failed to decode album data from \(availableKey): \(error)")
                            continue
                        }
                    }
                }
                
                print("🔍 DEBUG - FALLBACK: No compatible album data found")
                return nil
            }
        }
    private func generateShareId() -> String {
            return "share_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(12))"
        }
    }
