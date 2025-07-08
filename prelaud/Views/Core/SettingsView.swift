//
//  SettingsView.swift
//  MusicPreview
//
//  Created by Jan Lehmacher on 12.07.25.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var dataManager = DataPersistenceManager.shared
    @StateObject private var profileManager = UserProfileManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingCloudSync = false
    @State private var showingStorageInfo = false
    @State private var showingProfileEdit = false
    @State private var showingImagePicker = false
    
    var body: some View {
        ZStack {
            // Konsistenter schwarzer Background wie AlbumsView
            Color.black.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Konsistenter Header wie AlbumsView
                    settingsHeader
                        .padding(.top, 60)
                        .padding(.bottom, 40)
                    
                    // Profile Section (minimal und clean)
                    if let profile = profileManager.userProfile {
                        profileSection(profile: profile)
                            .padding(.bottom, 32)
                    }
                    
                    // Settings Content
                    settingsContent
                    
                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 24)
            }
        }
        .overlay(closeButton, alignment: .topTrailing)
        .alert("Enable Cloud Sync", isPresented: $showingCloudSync) {
            Button("Cancel", role: .cancel) { }
            Button("Enable") {
                HapticFeedbackManager.shared.success()
                dataManager.enableCloudSync()
            }
        } message: {
            Text("Sync your albums across all your devices. Your data stays secure and private.")
        }
        .sheet(isPresented: $showingStorageInfo) {
            StorageDetailView()
        }
        .sheet(isPresented: $showingProfileEdit) {
            ProfileEditView()
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: .init(
                get: { profileManager.userProfile?.profileImage },
                set: { newImage in
                    if let image = newImage {
                        profileManager.updateProfile(profileImage: image)
                        HapticFeedbackManager.shared.success()
                    }
                }
            ))
        }
    }
    
    // MARK: - Konsistenter Header
    private var settingsHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                Text("pre")
                    .font(.system(size: 28, weight: .thin, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .tracking(2.0)
                
                Text("laud")
                    .font(.system(size: 28, weight: .thin, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(2.0)
            }
            
            Text("settings")
                .font(.system(size: 11, weight: .light))
                .foregroundColor(.white.opacity(0.3))
                .tracking(0.5)
        }
    }
    
    // MARK: - Minimale Profile Section
    private func profileSection(profile: UserProfile) -> some View {
        VStack(spacing: 16) {
            // Profile Header - minimal
            HStack(spacing: 12) {
                // Kleineres Profilbild
                Button(action: { showingImagePicker = true }) {
                    Group {
                        if let profileImage = profile.profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.white.opacity(0.05)))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.1), lineWidth: 0.5))
                }
                .buttonStyle(MinimalButtonStyle())
                
                // Kompakte Profile Info
                VStack(alignment: .leading, spacing: 2) {
                    Text("@\(profile.username)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(profile.artistName)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                Button(action: { showingProfileEdit = true }) {
                    Text("edit")
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(0.5)
                }
                .buttonStyle(MinimalButtonStyle())
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(0.05), lineWidth: 0.5)
                    )
            )
        }
    }
    
    // MARK: - Settings Content
    private var settingsContent: some View {
        VStack(spacing: 24) {
            // Storage Section - minimal
            settingsSection(title: "storage") {
                storageInfoRow
            }
            
            // Albums Section - minimal
            settingsSection(title: "albums") {
                albumsInfoRow
            }
            
            // App Section - minimal
            settingsSection(title: "app") {
                VStack(spacing: 8) {
                    settingsRow(title: "about", subtitle: "v1.0") { }
                    settingsRow(title: "help", subtitle: "support") { }
                }
            }
        }
    }
    
    // MARK: - Minimal Settings Section
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .tracking(0.5)
            
            content()
        }
    }
    
    // MARK: - Storage Info Row
    private var storageInfoRow: some View {
        let storageInfo = dataManager.getStorageInfo()
        
        return settingsRow(
            title: "local storage",
            subtitle: "\(storageInfo.albumCount) albums"
        ) {
            showingStorageInfo = true
        }
    }
    
    // MARK: - Albums Info Row
    private var albumsInfoRow: some View {
        let albumCount = dataManager.savedAlbums.count
        let songCount = dataManager.savedAlbums.reduce(0) { $0 + $1.songs.count }
        
        return settingsRow(
            title: "\(albumCount) albums",
            subtitle: "\(songCount) songs"
        ) {
            showingStorageInfo = true
        }
    }
    
    // MARK: - Minimal Settings Row
    private func settingsRow(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.2))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(0.05), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(MinimalButtonStyle())
    }
    
    // MARK: - Close Button (minimaler)
    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(.white.opacity(0.03))
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.1), lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(MinimalButtonStyle())
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
}

// MARK: - Storage Detail View (vereinfacht)
struct StorageDetailView: View {
    @StateObject private var dataManager = DataPersistenceManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Minimaler Header
                HStack {
                    Button("back") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                    
                    Text("albums")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Button("") { }
                        .opacity(0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 32)
                
                // Albums Liste
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(dataManager.savedAlbums, id: \.id) { album in
                            AlbumStorageRow(album: album)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100)
                }
            }
        }
    }
}

struct AlbumStorageRow: View {
    let album: Album
    @StateObject private var dataManager = DataPersistenceManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Kleines Cover
            if let coverImage = album.coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.white.opacity(0.05))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.3))
                    )
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                
                Text("\(album.songs.count) songs")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Spacer()
            
            // Delete Button
            Button(action: {
                HapticFeedbackManager.shared.mediumImpact()
                dataManager.deleteAlbum(album)
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(MinimalButtonStyle())
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.white.opacity(0.05), lineWidth: 0.5)
                )
        )
    }
}

#Preview {
    SettingsView()
}
