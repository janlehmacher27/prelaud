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
    
    /// Lädt alle mit mir geteilten Alben
    func loadSharedAlbums() {
        guard let currentUser = UserProfileManager.shared.userProfile else { return }
        
        Task {
            isLoadingSharedAlbums = true
            
            do {
                let sharedRecords = try await fetchSharedAlbumsForUser(currentUser.id.uuidString)
                
                var albums: [Album] = []
                for record in sharedRecords {
                    if let album = try await loadAlbumData(shareId: record.shareId) {
                        // Setze Sharing-Informationen
                        var sharedAlbum = album
                        sharedAlbum.ownerId = record.ownerId
                        sharedAlbum.ownerUsername = record.ownerUsername
                        sharedAlbum.shareId = record.shareId
                        sharedAlbum.sharedAt = record.createdAt
                        sharedAlbum.sharePermissions = record.permissions
                        albums.append(sharedAlbum)
                    }
                }
                
                sharedWithMeAlbums = albums
                print("📥 Loaded \(albums.count) shared albums")
                
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
        // Lade Album-Daten basierend auf shareId
        if let data = UserDefaults.standard.data(forKey: "SharedAlbumData_\(shareId)"),
           let albumData = try? JSONDecoder().decode(EncodableAlbum.self, from: data) {
            return albumData.toAlbum()
        }
        return nil
    }
    
    private func generateShareId() -> String {
        return "share_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(12))"
    }
}
