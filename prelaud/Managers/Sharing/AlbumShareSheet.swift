//
//  AlbumShareSheet.swift - FIXED VERSION with onDismiss
//  prelaud
//
//  Enhanced Album Share Sheet mit vollständiger PocketBase Integration
//

import SwiftUI

struct AlbumShareSheet: View {
    let album: Album
    let onDismiss: () -> Void
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
                        onDismiss()
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
                .frame(width: 120, height: 120)
                .overlay(
                    Group {
                        if let coverImage = album.coverImage {
                            Image(uiImage: coverImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipped()
                                .cornerRadius(16)
                        } else {
                            Image(systemName: "music.note")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                )
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            
            VStack(spacing: 4) {
                Text(album.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text("by \(album.artist)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text("\(album.songs.count) song\(album.songs.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 20)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Username Input Section
    
    private var usernameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle")
                    .foregroundColor(.blue)
                Text("Share with")
                    .fontWeight(.medium)
            }
            
            TextField("Enter username", text: $targetUsername)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .overlay(
                    HStack {
                        Spacer()
                        if !targetUsername.isEmpty {
                            Button(action: { targetUsername = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                            .padding(.trailing, 8)
                        }
                    }
                )
            
            Text("The user will receive a sharing request notification")
                .font(.caption)
                .foregroundColor(.gray)
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
                Text("Permissions")
                    .fontWeight(.medium)
            }
            
            VStack(spacing: 16) {
                // Listen Permission
                HStack {
                    Image(systemName: "play.circle")
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Allow Listening")
                            .fontWeight(.medium)
                        Text("User can stream and play songs")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $canListen)
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                }
                
                // Download Permission
                HStack {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Allow Download")
                            .fontWeight(.medium)
                        Text("User can save songs locally")
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
                    onDismiss()
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
                    if let sharingError = error as? AlbumSharingError {
                        switch sharingError {
                        case .userNotFound:
                            errorMessage = "User '\(targetUsername)' not found"
                        case .albumNotFound:
                            errorMessage = "Album could not be found"
                        case .networkError(let details):
                            errorMessage = "Network error: \(details)"
                        case .permissionDenied:
                            errorMessage = "Permission denied"
                        case .invalidPermissions:
                            errorMessage = "Invalid sharing permissions"
                        case .alreadyShared:
                            errorMessage = "Album is already shared with this user"
                        }
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    
                    shareResult = .error(errorMessage)
                    logger.error("❌ Album sharing failed: \(errorMessage)")
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
                
                // Success Icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                VStack(spacing: 12) {
                    Text("Album Shared!")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("'\(album.title)' has been shared with @\(targetUsername)")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                
                // Share Details
                VStack(spacing: 8) {
                    HStack {
                        Text("Share ID:")
                            .fontWeight(.medium)
                        Spacer()
                        Text(shareId)
                            .font(.monospaced(.caption)())
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Songs:")
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(album.songs.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Shared with:")
                            .fontWeight(.medium)
                        Spacer()
                        Text("@\(targetUsername)")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                
                Text("The user will receive a notification and can accept or decline your sharing request.")
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

// MARK: - Album Sharing Error

enum AlbumSharingError: Error {
    case userNotFound
    case albumNotFound
    case networkError(String)
    case permissionDenied
    case invalidPermissions
    case alreadyShared
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
