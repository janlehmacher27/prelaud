//
//  AlbumShareSheet.swift
//  prelaud
//
//  Created by Jan Lehmacher on 15.07.25.
//


//
//  AlbumShareSheet.swift
//  prelaud
//
//  Sheet zum Teilen von Alben mit anderen Nutzern
//

import SwiftUI

struct AlbumShareSheet: View {
    let album: Album
    @Environment(\.dismiss) private var dismiss
    @StateObject private var sharingManager = SupabaseAlbumSharingManager.shared
    
    @State private var targetUsername = ""
    @State private var isSharing = false
    @State private var shareResult: String?
    @State private var shareError: String?
    @State private var permissions = SharePermissions()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Album Preview
                        albumPreview
                        
                        // Share Form
                        shareForm
                        
                        // Share Options
                        shareOptions
                        
                        // Share Button
                        shareButton
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Share Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticFeedbackManager.shared.lightImpact()
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }
    
    private var albumPreview: some View {
        VStack(spacing: 16) {
            // Cover
            if let coverImage = album.coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.05))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.4))
                    )
            }
            
            // Info
            VStack(spacing: 8) {
                Text(album.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("by \(album.artist)")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("\(album.songs.count) songs")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
    
    private var shareForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Share with")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                HStack {
                    Text("@")
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.white.opacity(0.4))
                    
                    TextField("Username", text: $targetUsername)
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.white)
                        .textFieldStyle(PlainTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Rectangle()
                    .fill(.white.opacity(0.2))
                    .frame(height: 0.5)
                
                if !targetUsername.isEmpty {
                    Text("Album will be shared with @\(targetUsername)")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    private var shareOptions: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permissions")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "play.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.6))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Allow listening")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text("User can play and listen to all songs")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: .constant(true))
                        .disabled(true) // Always enabled for basic sharing
                }
                
                Divider()
                    .background(.white.opacity(0.1))
                
                HStack {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.6))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Allow download")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text("User can download songs for offline listening")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { permissions.canDownload },
                        set: { 
                            permissions = SharePermissions(
                                canListen: permissions.canListen,
                                canDownload: $0,
                                expiresAt: permissions.expiresAt
                            )
                        }
                    ))
                    .tint(.blue)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.1), lineWidth: 0.5)
                    )
            )
        }
    }
    
    private var shareButton: some View {
        VStack(spacing: 16) {
            Button(action: shareAlbum) {
                HStack {
                    if isSharing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .medium))
                    }
                    
                    Text(isSharing ? "Sharing..." : "Share Album")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canShare ? .white : .white.opacity(0.3))
                )
            }
            .disabled(!canShare)
            .buttonStyle(MinimalButtonStyle())
            
            // Result Messages
            if let result = shareResult {
                Text("✅ \(result)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
            }
            
            if let error = shareError {
                Text("❌ \(error)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var canShare: Bool {
        !targetUsername.isEmpty && !isSharing
    }
    
    private func shareAlbum() {
        guard canShare else { return }
        
        isSharing = true
        shareResult = nil
        shareError = nil
        
        HapticFeedbackManager.shared.lightImpact()
        
        Task {
            do {
                let shareId = try await sharingManager.shareAlbum(
                    album, 
                    withUsername: targetUsername,
                    permissions: permissions
                )
                
                await MainActor.run {
                    isSharing = false
                    shareResult = "Album shared successfully with @\(targetUsername)!"
                    HapticFeedbackManager.shared.success()
                    
                    // Auto-dismiss after success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        dismiss()
                    }
                }
                
            } catch {
                await MainActor.run {
                    isSharing = false
                    shareError = error.localizedDescription
                    HapticFeedbackManager.shared.error()
                }
            }
        }
    }
}