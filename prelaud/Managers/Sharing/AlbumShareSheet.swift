//
//  AlbumShareSheet.swift - COMPLETE INTEGRATION
//  prelaud
//
//  Enhanced Album Share Sheet mit vollständiger PocketBase Integration
//

import SwiftUI

struct AlbumShareSheet: View {
    let album: Album
    @StateObject private var sharingManager = AlbumSharingManager.shared
    @StateObject private var logger = RemoteLogger.shared
    
    @State private var targetUsername = ""
    @State private var canListen = true
    @State private var canDownload = false
    @State private var hasExpiry = false
    @State private var expiryDate = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days
    @State private var isSharing = false
    @State private var shareResult: ShareResult?
    @State private var showingSuccessSheet = false
    
    @Environment(\.dismiss) private var dismiss
    
    enum ShareResult {
        case success(String) // shareId
        case error(String)   // error message
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with Album Info
                albumHeader
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Username Input Section
                        usernameSection
                        
                        // Permissions Section
                        permissionsSection
                        
                        // Share Button
                        shareButton
                        
                        // Result Section
                        if let result = shareResult {
                            resultSection(result)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Share Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingSuccessSheet) {
            if case .success(let shareId) = shareResult {
                ShareSuccessSheet(
                    album: album,
                    targetUsername: targetUsername,
                    shareId: shareId
                )
            }
        }
    }
    
    // MARK: - Album Header
    
    private var albumHeader: some View {
        VStack(spacing: 12) {
            // Album Cover
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.8))
                )
            
            // Album Info
            VStack(spacing: 4) {
                Text(album.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("by \(album.artist)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text("\(album.songs.count) songs")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Username Section
    
    private var usernameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text("Share with")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                TextField("Enter username", text: $targetUsername)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .onChange(of: targetUsername) { oldValue, newValue in
                        // Remove @ symbol if user types it
                        if newValue.hasPrefix("@") {
                            targetUsername = String(newValue.dropFirst())
                        }
                    }
                
                Text("Enter the username without the @ symbol")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - Permissions Section
    
    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lock.shield")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text("Permissions")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 16) {
                // Listen Permission
                HStack {
                    Image(systemName: "play.circle")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Allow Listening")
                            .fontWeight(.medium)
                        Text("User can stream the album")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $canListen)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
                
                // Download Permission
                HStack {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Allow Download")
                            .fontWeight(.medium)
                        Text("User can download songs")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $canDownload)
                        .toggleStyle(SwitchToggleStyle(tint: .orange))
                }
                
                // Expiry Permission
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.purple)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Set Expiry Date")
                            .fontWeight(.medium)
                        Text("Auto-revoke access after date")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $hasExpiry)
                        .toggleStyle(SwitchToggleStyle(tint: .purple))
                }
                
                // Date Picker (when expiry is enabled)
                if hasExpiry {
                    DatePicker(
                        "Expires on",
                        selection: $expiryDate,
                        in: Date()...,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(CompactDatePickerStyle())
                    .padding(.leading, 32)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - Share Button
    
    private var shareButton: some View {
        Button(action: shareAlbum) {
            HStack {
                if isSharing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                
                Image(systemName: "square.and.arrow.up")
                Text(isSharing ? "Sharing..." : "Share Album")
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: canShare ? [.blue, .purple] : [.gray, .gray],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .foregroundColor(.white)
            .font(.headline)
        }
        .disabled(!canShare || isSharing)
        .animation(.easeInOut(duration: 0.2), value: canShare)
    }
    
    private var canShare: Bool {
        !targetUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (canListen || canDownload)
    }
    
    // MARK: - Result Section
    
    private func resultSection(_ result: ShareResult) -> some View {
        VStack(spacing: 12) {
            switch result {
            case .success(let shareId):
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    
                    Text("Album Shared Successfully!")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    
                    Text("'\(album.title)' has been shared with @\(targetUsername)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Text("Share ID: \(shareId)")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
                
            case .error(let message):
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                    
                    Text("Sharing Failed")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                    
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            }
            
            Button(result.isSuccess ? "Done" : "Try Again") {
                if result.isSuccess {
                    dismiss()
                } else {
                    shareResult = nil
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Share Action
    
    private func shareAlbum() {
        guard canShare else { return }
        
        isSharing = true
        shareResult = nil
        
        logger.info("🔗 Starting album share for '\(album.title)' to @\(targetUsername)")
        
        Task {
            do {
                let permissions = SharePermissions(
                    canListen: canListen,
                    canDownload: canDownload,
                    expiresAt: hasExpiry ? expiryDate : nil
                )
                
                let shareId = try await sharingManager.createSharingRequest(
                    album,
                    targetUsername: targetUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                    permissions: permissions
                )
                
                await MainActor.run {
                    shareResult = .success(shareId)
                    logger.success("✅ Album shared successfully: \(shareId)")
                    
                    // Auto-show success sheet after a moment
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        showingSuccessSheet = true
                    }
                }
                
            } catch {
                await MainActor.run {
                    let errorMessage: String
                    if let sharingError = error as? SharingError {
                        errorMessage = sharingError.localizedDescription
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    
                    shareResult = .error(errorMessage)
                    logger.error("❌ Album sharing failed: \(error)")
                }
            }
            
            await MainActor.run {
                isSharing = false
            }
        }
    }
}

// MARK: - Share Success Sheet
struct ShareSuccessSheet: View {
    let album: Album
    let targetUsername: String
    let shareId: String
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                // Success Animation
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                        .scaleEffect(1.0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: true)
                    
                    Text("Successfully Shared!")
                        .font(.title)
                        .fontWeight(.bold)
                }
                
                // Share Details
                VStack(spacing: 12) {
                    HStack {
                        Text("Album:")
                        Spacer()
                        Text(album.title)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Shared with:")
                        Spacer()
                        Text("@\(targetUsername)")
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("Share ID:")
                        Spacer()
                        Text(shareId)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Text("The user will receive a sharing request and can accept or decline it.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .navigationTitle("Share Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Extensions

extension AlbumShareSheet.ShareResult {
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
}
