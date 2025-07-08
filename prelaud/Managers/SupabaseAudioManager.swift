//
//  SupabaseAudioManager.swift - COMPLETE FIX
//  MusicPreview
//
//  Fixed authentication, error handling, and audio playback
//

import Foundation
import SwiftUI

@MainActor
class SupabaseAudioManager: ObservableObject {
    static let shared = SupabaseAudioManager()
    
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var uploadedFiles: [String: String] = [:]
    @Published var currentUploadStatus = ""
    
    // Your Supabase Credentials
    private let supabaseURL = "https://auzsunnwanzljiwdpzov.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1enN1bm53YW56bGppd2Rwem92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIxMzIyNjksImV4cCI6MjA2NzcwODI2OX0.UmuoVT-7uXq5SMFr9duiurbE52Oe865w4ghYPkFwexE"
    
    private var urlSession: URLSession
    private var progressTimer: Timer?
    private var activeTasks: [String: URLSessionTask] = [:]
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120.0
        config.timeoutIntervalForResource = 600.0
        config.allowsCellularAccess = true
        urlSession = URLSession(configuration: config)
        loadUploadedFiles()
    }
    
    // MARK: - Upload Audio File (FIXED)
    func uploadAudioFile(_ fileURL: URL, filename: String, songId: String? = nil) async throws -> String {
        print("🚀 Starting Supabase upload for: \(filename)")
        
        let usedSongId = songId ?? UUID().uuidString
        
        await MainActor.run {
            isUploading = true
            uploadProgress = 0
            currentUploadStatus = "Preparing upload..."
        }
        
        do {
            // Read audio file
            await MainActor.run {
                currentUploadStatus = "Reading audio file..."
            }
            
            let audioData = try Data(contentsOf: fileURL)
            let fileSizeMB = Double(audioData.count) / (1024 * 1024)
            
            print("💾 Audio data size: \(String(format: "%.1f", fileSizeMB)) MB")
            
            await MainActor.run {
                currentUploadStatus = "Uploading \(String(format: "%.1f", fileSizeMB)) MB..."
            }
            
            // Check file size
            guard audioData.count < 50 * 1024 * 1024 else {
                await MainActor.run {
                    currentUploadStatus = "File too large (max 50MB)"
                    isUploading = false
                }
                throw SupabaseError.fileTooLarge
            }
            
            // Upload details
            let bucketName = "audio-files"
            let fileExtension = fileURL.pathExtension.lowercased()
            let filePath = "\(usedSongId).\(fileExtension)"
            let uploadURL = URL(string: "\(supabaseURL)/storage/v1/object/\(bucketName)/\(filePath)")!
            
            print("📤 Uploading to: \(uploadURL)")
            
            // FIXED: Use correct headers based on debug output
            var request = URLRequest(url: uploadURL)
            request.httpMethod = "POST"
            request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
            request.setValue(getContentType(for: fileExtension), forHTTPHeaderField: "Content-Type")
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("true", forHTTPHeaderField: "x-upsert") // Fixed upsert header
            
            // Start progress simulation
            await startProgressSimulation()
            
            // Create upload task
            let uploadTask = urlSession.uploadTask(with: request, from: audioData)
            activeTasks[usedSongId] = uploadTask
            
            // Perform upload
            let (data, response) = try await urlSession.upload(for: request, from: audioData)
            
            // Remove from active tasks
            activeTasks.removeValue(forKey: usedSongId)
            
            // Stop progress simulation
            stopProgressSimulation()
            
            // Evaluate response
            if let httpResponse = response as? HTTPURLResponse {
                print("📋 HTTP Status: \(httpResponse.statusCode)")
                
                if !data.isEmpty {
                    let responseString = String(data: data, encoding: .utf8) ?? "No response"
                    print("📄 Response: \(responseString)")
                }
                
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    // Success! Generate Public URL
                    let publicURL = "\(supabaseURL)/storage/v1/object/public/\(bucketName)/\(filePath)"
                    
                    await MainActor.run {
                        // Save URL locally
                        uploadedFiles[usedSongId] = publicURL
                        currentUploadStatus = "Upload complete!"
                        uploadProgress = 1.0
                    }
                    
                    // Reset after 2 seconds
                    Task {
                        try await Task.sleep(nanoseconds: 2_000_000_000)
                        await MainActor.run {
                            self.isUploading = false
                            self.uploadProgress = 0
                            self.currentUploadStatus = ""
                        }
                    }
                    
                    saveUploadedFiles()
                    print("✅ Supabase upload successful: \(publicURL)")
                    
                    return publicURL
                } else {
                    print("❌ HTTP Error: \(httpResponse.statusCode)")
                    
                    // Parse error response
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorData["message"] as? String {
                        print("❌ Error message: \(errorMessage)")
                    }
                    
                    throw SupabaseError.uploadFailed
                }
            } else {
                print("❌ Invalid response")
                throw SupabaseError.networkError
            }
            
        } catch {
            await MainActor.run {
                isUploading = false
                uploadProgress = 0
                
                let errorMessage: String
                if let supabaseError = error as? SupabaseError {
                    errorMessage = supabaseError.localizedDescription
                } else {
                    errorMessage = error.localizedDescription
                }
                
                currentUploadStatus = "Upload failed: \(errorMessage)"
                
                // Reset after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.currentUploadStatus = ""
                }
            }
            
            // Remove from active tasks
            activeTasks.removeValue(forKey: usedSongId)
            stopProgressSimulation()
            
            print("❌ Supabase upload failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Content Type Detection
    private func getContentType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "mp3":
            return "audio/mpeg"
        case "m4a":
            return "audio/mp4"
        case "wav":
            return "audio/wav"
        case "aiff", "aif":
            return "audio/aiff"
        case "flac":
            return "audio/flac"
        case "ogg":
            return "audio/ogg"
        default:
            return "audio/mpeg"
        }
    }
    
    // MARK: - Progress Simulation (FIXED)
    private func startProgressSimulation() async {
        await stopProgressSimulation()
        
        await MainActor.run {
            progressTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                
                Task { @MainActor in
                    if self.uploadProgress < 0.85 && self.isUploading {
                        let increment = Double.random(in: 0.02...0.05)
                        self.uploadProgress = min(0.85, self.uploadProgress + increment)
                        
                        let percentage = Int(self.uploadProgress * 100)
                        if self.uploadProgress < 0.3 {
                            self.currentUploadStatus = "Uploading... \(percentage)%"
                        } else if self.uploadProgress < 0.6 {
                            self.currentUploadStatus = "Processing... \(percentage)%"
                        } else {
                            self.currentUploadStatus = "Finalizing... \(percentage)%"
                        }
                    }
                    
                    if !self.isUploading || self.uploadProgress >= 1.0 {
                        self.stopProgressSimulation()
                    }
                }
            }
        }
    }
    
    private func stopProgressSimulation() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    // MARK: - URL Validation and Playback
    func getPlaybackURL(for song: Song) -> URL? {
        // Try by songId first
        if let songId = song.songId,
           let supabaseURL = uploadedFiles[songId],
           let url = URL(string: supabaseURL) {
            print("🎵 Found Supabase URL for songId \(songId): \(supabaseURL)")
            return isValidAudioURL(url) ? url : nil
        }
        
        // Try by audioFileName
        if let audioFileName = song.audioFileName,
           let supabaseURL = uploadedFiles[audioFileName],
           let url = URL(string: supabaseURL) {
            print("🎵 Found Supabase URL for filename \(audioFileName): \(supabaseURL)")
            return isValidAudioURL(url) ? url : nil
        }
        
        print("🎵 No Supabase URL found for song: \(song.title)")
        return nil
    }
    
    private func isValidAudioURL(_ url: URL) -> Bool {
        // For Supabase URLs, trust they are valid
        if url.absoluteString.contains("supabase.co") {
            return true
        }
        
        // For other URLs, check extension
        let supportedExtensions = ["mp3", "m4a", "wav", "aiff", "flac", "ogg"]
        let pathExtension = url.pathExtension.lowercased()
        return supportedExtensions.contains(pathExtension) || pathExtension.isEmpty
    }
    
    // MARK: - Cancel Upload
    func cancelUpload(for songId: String) {
        // Cancel active task
        if let task = activeTasks[songId] {
            task.cancel()
            activeTasks.removeValue(forKey: songId)
            print("⏹️ Cancelled upload for songId: \(songId)")
        }
        
        Task { @MainActor in
            isUploading = false
            uploadProgress = 0
            currentUploadStatus = "Upload cancelled"
            stopProgressSimulation()
            
            Task {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    self.currentUploadStatus = ""
                }
            }
        }
    }
    
    // MARK: - Persistence
    func saveUploadedFiles() {
        UserDefaults.standard.set(uploadedFiles, forKey: "SupabaseUploadedFiles")
        print("💾 Saved \(uploadedFiles.count) uploaded files to UserDefaults")
    }
    
    func loadUploadedFiles() {
        if let saved = UserDefaults.standard.object(forKey: "SupabaseUploadedFiles") as? [String: String] {
            uploadedFiles = saved
            print("📂 Loaded \(uploadedFiles.count) uploaded files from UserDefaults")
        }
    }
    
    // MARK: - Migration and Cleanup
    func migrateFromDropbox() {
        // Migrate old Dropbox files to new format
        if let dropboxFiles = UserDefaults.standard.object(forKey: "DropboxUploadedFiles") as? [String: String] {
            for (key, value) in dropboxFiles {
                if uploadedFiles[key] == nil {
                    uploadedFiles[key] = value
                }
            }
            saveUploadedFiles()
            UserDefaults.standard.removeObject(forKey: "DropboxUploadedFiles")
            print("🔄 Migrated \(dropboxFiles.count) files from Dropbox")
        }
    }
    
    // MARK: - Health Check
    func performHealthCheck() async -> Bool {
        do {
            let healthURL = URL(string: "\(supabaseURL)/rest/v1/")!
            var request = URLRequest(url: healthURL)
            request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
            
            let (_, response) = try await urlSession.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                let isHealthy = httpResponse.statusCode == 200 || httpResponse.statusCode == 404
                print(isHealthy ? "✅ Supabase health check passed" : "⚠️ Supabase health check failed: \(httpResponse.statusCode)")
                return isHealthy
            }
            
            return false
        } catch {
            print("❌ Supabase health check error: \(error)")
            return false
        }
    }
    
    // MARK: - File Management
    func deleteFile(songId: String) async throws {
        guard let fileURL = uploadedFiles[songId] else {
            throw SupabaseError.fileNotFound
        }
        
        // Extract file path from URL
        guard let url = URL(string: fileURL),
              let pathComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)?.path.components(separatedBy: "/"),
              pathComponents.count >= 4 else {
            throw SupabaseError.invalidFile
        }
        
        let bucketName = pathComponents[pathComponents.count - 2]
        let fileName = pathComponents.last!
        
        let deleteURL = URL(string: "\(supabaseURL)/storage/v1/object/\(bucketName)/\(fileName)")!
        
        var request = URLRequest(url: deleteURL)
        request.httpMethod = "DELETE"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await urlSession.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                uploadedFiles.removeValue(forKey: songId)
                saveUploadedFiles()
                print("🗑️ Successfully deleted file for songId: \(songId)")
            } else {
                print("❌ Failed to delete file: \(httpResponse.statusCode)")
                throw SupabaseError.deletionFailed
            }
        }
    }
}

// MARK: - Enhanced Error Types
enum SupabaseError: LocalizedError {
    case uploadFailed
    case invalidFile
    case fileTooLarge
    case timeout
    case networkError
    case authenticationError
    case bucketNotFound
    case fileNotFound
    case deletionFailed
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .uploadFailed:
            return "Upload to Supabase failed"
        case .invalidFile:
            return "Invalid audio file"
        case .fileTooLarge:
            return "File too large (max 50MB)"
        case .timeout:
            return "Upload timeout"
        case .networkError:
            return "Network error occurred"
        case .authenticationError:
            return "Authentication failed"
        case .bucketNotFound:
            return "Storage bucket not found"
        case .fileNotFound:
            return "File not found"
        case .deletionFailed:
            return "Failed to delete file"
        case .invalidResponse:
            return "Invalid server response"
        }
    }
}
