//
//  AudioManager.swift - COMPLETE WITH METADATA SUPPORT
//  prelaud
//
//  PocketBase Audio File Management with proper owner handling and metadata
//

import Foundation
import SwiftUI

@MainActor
class AudioManager: ObservableObject {
    static let shared = AudioManager()
    
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var uploadedFiles: [String: String] = [:]
    @Published var currentUploadStatus = ""
    
    private let pocketBase = PocketBaseManager.shared
    private var progressTimer: Timer?
    private var activeTasks: [String: URLSessionTask] = [:]
    
    private init() {
        loadUploadedFiles()
    }
    
    // MARK: - Upload Audio File (UPDATED WITH OWNER VERIFICATION)
    
    func uploadAudioFile(_ fileURL: URL, filename: String, songId: String? = nil) async throws -> String {
        let usedSongId = songId ?? UUID().uuidString
        
        // VERIFY USER IS PROPERLY SETUP
        guard let userProfile = UserProfileManager.shared.userProfile else {
            currentUploadStatus = "No user profile found"
            isUploading = false
            throw AudioError.uploadFailed
        }
        
        guard let cloudId = userProfile.cloudId else {
            currentUploadStatus = "User not properly synced with cloud"
            isUploading = false
            throw AudioError.uploadFailed
        }
        
        print("🎵 Starting upload for user: @\(userProfile.username) (cloudId: \(cloudId))")
        
        isUploading = true
        uploadProgress = 0
        currentUploadStatus = "Preparing upload..."
        
        do {
            currentUploadStatus = "Reading audio file..."
            
            let audioData = try Data(contentsOf: fileURL)
            let fileSizeMB = Double(audioData.count) / (1024 * 1024)
            
            currentUploadStatus = "Uploading \(String(format: "%.1f", fileSizeMB)) MB for @\(userProfile.username)..."
            
            // Check file size (PocketBase default limit is usually 50MB)
            guard audioData.count < 50 * 1024 * 1024 else {
                currentUploadStatus = "File too large (max 50MB)"
                isUploading = false
                throw AudioError.fileTooLarge
            }
            
            startProgressSimulation()
            
            // Upload to PocketBase with verified owner
            let fileId = try await pocketBase.uploadAudioFile(
                data: audioData,
                filename: filename,
                songId: usedSongId
            )
            
            // Store mapping locally
            uploadedFiles[usedSongId] = fileId
            saveUploadedFiles()
            
            stopProgressSimulation()
            uploadProgress = 1.0
            currentUploadStatus = "Upload completed for @\(userProfile.username)!"
            isUploading = false
            
            print("✅ Audio file uploaded successfully:")
            print("  - User: @\(userProfile.username)")
            print("  - CloudId: \(cloudId)")
            print("  - FileId: \(fileId)")
            print("  - SongId: \(usedSongId)")
            
            // Clear status after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.currentUploadStatus = ""
            }
            
            return fileId
            
        } catch {
            stopProgressSimulation()
            isUploading = false
            currentUploadStatus = "Upload failed: \(error.localizedDescription)"
            
            print("❌ Upload failed for user @\(userProfile.username): \(error)")
            
            // Clear error after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.currentUploadStatus = ""
            }
            
            throw error
        }
    }
    
    // MARK: - NEW: Upload Audio File With Metadata
    
    func uploadAudioFileWithMetadata(_ fileURL: URL, filename: String, songId: String, displayName: String, uploadedAt: Date) async throws -> String {
        let usedSongId = songId
        
        // VERIFY USER IS PROPERLY SETUP
        guard let userProfile = UserProfileManager.shared.userProfile else {
            currentUploadStatus = "No user profile found"
            isUploading = false
            throw AudioError.uploadFailed
        }
        
        guard let cloudId = userProfile.cloudId else {
            currentUploadStatus = "User not properly synced with cloud"
            isUploading = false
            throw AudioError.uploadFailed
        }
        
        print("🎵 Starting upload with metadata for user: @\(userProfile.username) (cloudId: \(cloudId))")
        print("📋 Metadata: displayName=\(displayName), uploadedAt=\(uploadedAt)")
        
        isUploading = true
        uploadProgress = 0
        currentUploadStatus = "Preparing upload..."
        
        do {
            currentUploadStatus = "Reading audio file..."
            
            let audioData = try Data(contentsOf: fileURL)
            let fileSizeMB = Double(audioData.count) / (1024 * 1024)
            
            currentUploadStatus = "Uploading \(String(format: "%.1f", fileSizeMB)) MB for @\(userProfile.username)..."
            
            // Check file size (PocketBase default limit is usually 50MB)
            guard audioData.count < 50 * 1024 * 1024 else {
                currentUploadStatus = "File too large (max 50MB)"
                isUploading = false
                throw AudioError.fileTooLarge
            }
            
            startProgressSimulation()
            
            // Upload to PocketBase with verified owner and metadata
            let formatter = ISO8601DateFormatter()
            let uploadedAtString = formatter.string(from: uploadedAt)

            let fileId = try await pocketBase.uploadAudioFileWithMetadata(
                fileURL,
                filename: filename,
                songId: usedSongId,
                displayName: displayName,
                uploadedAt: uploadedAtString  // ✅ String
            )
            // Store mapping locally
            uploadedFiles[usedSongId] = fileId
            saveUploadedFiles()
            
            stopProgressSimulation()
            uploadProgress = 1.0
            currentUploadStatus = "Upload completed for @\(userProfile.username)!"
            isUploading = false
            
            print("✅ Audio file with metadata uploaded successfully:")
            print("  - User: @\(userProfile.username)")
            print("  - CloudId: \(cloudId)")
            print("  - FileId: \(fileId)")
            print("  - SongId: \(usedSongId)")
            print("  - DisplayName: \(displayName)")
            print("  - UploadedAt: \(uploadedAt)")
            
            // Clear status after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.currentUploadStatus = ""
            }
            
            return fileId
            
        } catch {
            stopProgressSimulation()
            isUploading = false
            currentUploadStatus = "Upload failed: \(error.localizedDescription)"
            
            print("❌ Upload with metadata failed for user @\(userProfile.username): \(error)")
            
            // Clear error after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.currentUploadStatus = ""
            }
            
            throw error
        }
    }
    
    // MARK: - Get Audio URL
    
    func getAudioURL(for song: Song) async -> URL? {
        // Try by songId first
        if let songId = song.songId {
            return try? await pocketBase.getAudioFileURL(songId: songId)
        }
        
        // Try by audioFileName
        if let audioFileName = song.audioFileName,
           let fileId = uploadedFiles[audioFileName] {
            return try? await pocketBase.getAudioFileURL(songId: fileId)
        }
        
        return nil
    }
    
    // MARK: - Progress Simulation
    
    private func startProgressSimulation() {
        progressTimer?.invalidate()
        
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                if self.uploadProgress < 0.9 {
                    self.uploadProgress += Double.random(in: 0.05...0.15)
                }
            }
        }
    }
    
    private func stopProgressSimulation() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    // MARK: - Cancel Upload
    
    func cancelUpload(for songId: String) {
        if let task = activeTasks[songId] {
            task.cancel()
            activeTasks.removeValue(forKey: songId)
        }
        
        isUploading = false
        uploadProgress = 0
        currentUploadStatus = "Upload cancelled"
        stopProgressSimulation()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.currentUploadStatus = ""
        }
    }
    
    // MARK: - Persistence
    
    func saveUploadedFiles() {
        UserDefaults.standard.set(uploadedFiles, forKey: "PocketBaseUploadedFiles")
    }
    
    func loadUploadedFiles() {
        if let saved = UserDefaults.standard.object(forKey: "PocketBaseUploadedFiles") as? [String: String] {
            uploadedFiles = saved
        }
    }
    
    // MARK: - Migration from Supabase
    
    func migrateFromSupabase() {
        // Migrate old Supabase files to new format
        if let supabaseFiles = UserDefaults.standard.object(forKey: "SupabaseUploadedFiles") as? [String: String] {
            for (key, value) in supabaseFiles {
                if uploadedFiles[key] == nil {
                    uploadedFiles[key] = value
                }
            }
            saveUploadedFiles()
            UserDefaults.standard.removeObject(forKey: "SupabaseUploadedFiles")
        }
    }
    
    // MARK: - Health Check
    
    func performHealthCheck() async -> Bool {
        return pocketBase.isConnected
    }
    
    // MARK: - Debug Functions
    
    func debugUploadReadiness() async {
        print("🔍 DEBUGGING: Upload Readiness Check")
        print(String(repeating: "=", count: 40))
        
        if let userProfile = UserProfileManager.shared.userProfile {
            print("✅ UserProfile: @\(userProfile.username)")
            print("  - Local ID: \(userProfile.id)")
            print("  - Cloud ID: \(userProfile.cloudId ?? "❌ MISSING")")
            print("  - Artist: \(userProfile.artistName)")
            
            if userProfile.cloudId != nil {
                print("✅ User is ready for uploads")
            } else {
                print("❌ User missing cloudId - uploads will fail!")
            }
        } else {
            print("❌ No user profile found!")
        }
        
        // Test PocketBase connection
        let isConnected = await pocketBase.performHealthCheck()
        print("📡 PocketBase connection: \(isConnected ? "✅ Connected" : "❌ Failed")")
        
        print(String(repeating: "=", count: 40))
    }
}

// MARK: - Errors

enum AudioError: Error, LocalizedError {
    case fileTooLarge
    case uploadFailed
    case fileNotFound
    case invalidFile
    case networkError
    case userNotSetup  // NEW: For when user isn't properly configured
    
    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            return "File is too large (max 50MB)"
        case .uploadFailed:
            return "Failed to upload file"
        case .fileNotFound:
            return "File not found"
        case .invalidFile:
            return "Invalid audio file"
        case .networkError:
            return "Network error"
        case .userNotSetup:
            return "User profile not properly configured"
        }
    }
}
