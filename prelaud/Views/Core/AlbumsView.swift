//
//  AlbumsView.swift - CORRECTED WITH SHARE AND 3-DOTS MENUS
//  MusicPreview
//
//  Fixed to include both existing functionality and share feature
//

import SwiftUI

struct AlbumsView: View {
    @Binding var albums: [Album]
    @Binding var selectedService: StreamingService
    @Binding var showingSettings: Bool
    @Binding var currentAlbum: Album?
    let onCreateAlbum: () -> Void
    
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    @StateObject private var profileManager = UserProfileManager.shared
    @StateObject private var supabaseManager = SupabaseAudioManager.shared
    @StateObject private var dataManager = DataPersistenceManager.shared
    @State private var selectedTab: AlbumTab = .myAlbums
    @State private var sharedAlbums: [Album] = []
    
    // SHARE SHEET STATE
    @State private var showingShareSheet = false
    @State private var albumToShare: Album?
    
    #if DEBUG
    @State private var debugTapCount = 0
    #endif
    
    enum AlbumTab: String, CaseIterable {
        case myAlbums = "my albums"
        case shared = "shared"
    }
    
    // Artist name für Discography (aus Profil)
    private var artistName: String {
        profileManager.displayName
    }
    
    // Current albums based on selected tab
    private var currentAlbums: [Album] {
        switch selectedTab {
        case .myAlbums:
            return albums
        case .shared:
            return sharedAlbums
        }
    }
    
    var body: some View {
        ZStack {
            // Service-spezifischer Background
            serviceBackground
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Minimal Header (prelaud branding)
                    minimalHeader
                        .padding(.top, 60)
                        .padding(.bottom, 32)
                    
                    // Service Selector
                    MinimalServiceSelector(selectedService: $selectedService)
                        .padding(.bottom, 24)
                    
                    // Album Tab Selector
                    albumTabSelector
                        .padding(.bottom, 40)
                    
                    // Streaming-Style Discography
                    streamingDiscography
                    
                    // MINIMAL SETTINGS ACCESS - Ganz unten
                    minimalSettingsAccess
                        .padding(.top, 40)
                        .padding(.bottom, audioPlayer.currentSong != nil ? 140 : 60)
                }
                .padding(.horizontal, 24)
            }
            
            // FIXED Mini Player Overlay
            VStack {
                Spacer()
                
                if audioPlayer.currentSong != nil {
                    AdaptiveMiniPlayer(service: selectedService)
                        .padding(.bottom, 0)
                        .background(
                            Rectangle()
                                .fill(.clear)
                                .background(.ultraThinMaterial.opacity(0.1))
                                .ignoresSafeArea(.container, edges: .bottom)
                        )
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .onAppear {
            #if DEBUG
            debugSupabaseConnection()
            #endif
            
            supabaseManager.migrateFromDropbox()
            
            if albums.isEmpty {
                albums = dataManager.savedAlbums
            }
            loadSharedAlbums()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        // SHARE SHEET INTEGRATION
        .sheet(isPresented: $showingShareSheet) {
            ZStack {
                Color.green.ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("SIMPLE TEST")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                    
                    if let album = albumToShare {
                        Text("Album: \(album.title)")
                            .foregroundColor(.white)
                    } else {
                        Text("NO ALBUM FOUND")
                            .foregroundColor(.white)
                    }
                    
                    Button("Close") {
                        showingShareSheet = false
                    }
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Album Tab Selector
    private var albumTabSelector: some View {
        HStack(spacing: 0) {
            ForEach(AlbumTab.allCases, id: \.self) { tab in
                Button(action: {
                    HapticFeedbackManager.shared.selection()
                    withAnimation(.smooth(duration: 0.3)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .ultraLight, design: .monospaced))
                            .foregroundColor(selectedTab == tab ? headerTextColor.opacity(0.8) : headerTextColor.opacity(0.25))
                            .tracking(1.0)
                        
                        // Underline indicator
                        Rectangle()
                            .fill(selectedTab == tab ? headerTextColor.opacity(0.6) : Color.clear)
                            .frame(height: 0.5)
                            .animation(.smooth(duration: 0.3), value: selectedTab)
                    }
                }
                .buttonStyle(MinimalButtonStyle())
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Service Background
    private var serviceBackground: some View {
        Group {
            switch selectedService {
            case .spotify:
                SpotifyBackground()
            case .appleMusic:
                AppleMusicBackground()
            case .amazonMusic:
                AmazonMusicBackground()
            case .youtubeMusic:
                YouTubeMusicBackground()
            }
        }
        .ignoresSafeArea()
        .animation(.smooth(duration: 0.6), value: selectedService)
    }
    
    // MARK: - Minimal Header
    private var minimalHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                Text("pre")
                    .font(.system(size: 28, weight: .thin, design: .monospaced))
                    .foregroundColor(headerTextColor.opacity(0.9))
                    .tracking(2.0)
                    .onTapGesture {
                        #if DEBUG
                        debugTapCount += 1
                        if debugTapCount >= 5 {
                            HapticFeedbackManager.shared.heavyImpact()
                            UserProfileManager.shared.resetProfileForFirstTimeSetup()
                            debugTapCount = 0
                        }
                        #endif
                    }
                
                Text("laud")
                    .font(.system(size: 28, weight: .thin, design: .monospaced))
                    .foregroundColor(headerTextColor.opacity(0.5))
                    .tracking(2.0)
            }
            
            // MINIMALER PROFILE HINT - nur bei Profil vorhanden
            if let profile = profileManager.userProfile {
                Text("@\(profile.username)")
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(headerTextColor.opacity(0.3))
                    .tracking(0.5)
            } else {
                Text("your music library")
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(headerTextColor.opacity(0.3))
            }
        }
    }
    
    // MARK: - Streaming Discography
    private var streamingDiscography: some View {
        Group {
            if currentAlbums.isEmpty {
                emptyState
            } else {
                VStack(spacing: 24) {
                    // Artist Header (only for My Albums)
                    if selectedTab == .myAlbums {
                        artistHeader
                    }
                    
                    // Albums Grid
                    albumsGrid
                    
                    // Add Album Button (only for My Albums)
                    if selectedTab == .myAlbums {
                        addAlbumButton
                    }
                }
            }
        }
    }
    
    // MARK: - Artist Header (Streaming Style)
    private var artistHeader: some View {
        Group {
            switch selectedService {
            case .spotify:
                EmptyView() // Kein Header für Spotify
            case .appleMusic:
                AppleMusicArtistHeader(artistName: artistName, albumCount: albums.count, profileManager: profileManager)
            case .amazonMusic:
                AmazonMusicArtistHeader(artistName: artistName, albumCount: albums.count, profileManager: profileManager)
            case .youtubeMusic:
                YouTubeMusicArtistHeader(artistName: artistName, albumCount: albums.count, profileManager: profileManager)
            }
        }
        .animation(.smooth(duration: 0.6), value: selectedService)
    }
    
    // MARK: - Albums Grid (Service Style)
    private var albumsGrid: some View {
        Group {
            switch selectedService {
            case .spotify:
                SpotifyAlbumsGrid(
                    albums: currentAlbums,
                    onAlbumTap: { album in
                        HapticFeedbackManager.shared.cardTap()
                        withAnimation(.smooth(duration: 0.4)) {
                            currentAlbum = album
                        }
                    },
                    onShareAlbum: shareAlbum // SHARE FUNCTION HINZUGEFÜGT
                )
            case .appleMusic:
                AppleMusicAlbumsGrid(
                    albums: currentAlbums,
                    onAlbumTap: { album in
                        HapticFeedbackManager.shared.cardTap()
                        withAnimation(.smooth(duration: 0.4)) {
                            currentAlbum = album
                        }
                    },
                    onShareAlbum: shareAlbum // SHARE FUNCTION HINZUGEFÜGT
                )
            case .amazonMusic:
                AmazonMusicAlbumsGrid(
                    albums: currentAlbums,
                    onAlbumTap: { album in
                        HapticFeedbackManager.shared.cardTap()
                        withAnimation(.smooth(duration: 0.4)) {
                            currentAlbum = album
                        }
                    },
                    onShareAlbum: shareAlbum // SHARE FUNCTION HINZUGEFÜGT
                )
            case .youtubeMusic:
                YouTubeMusicAlbumsGrid(
                    albums: currentAlbums,
                    onAlbumTap: { album in
                        HapticFeedbackManager.shared.cardTap()
                        withAnimation(.smooth(duration: 0.4)) {
                            currentAlbum = album
                        }
                    },
                    onShareAlbum: shareAlbum // SHARE FUNCTION HINZUGEFÜGT
                )
            }
        }
        .animation(.smooth(duration: 0.6), value: selectedService)
        .animation(.smooth(duration: 0.3), value: selectedTab)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Tab-specific empty state
            Group {
                switch selectedTab {
                case .myAlbums:
                    // Service-spezifisches Empty State Icon
                    Image(systemName: selectedService == .appleMusic ? "music.note" : "music.note")
                        .font(.system(size: 48, weight: .ultraLight))
                        .foregroundColor(headerTextColor.opacity(0.3))
                    
                    VStack(spacing: 16) {
                        Text("No Albums Yet")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(headerTextColor.opacity(0.8))
                        
                        Text("Create your first album to see it appear in your discography")
                            .font(.system(size: 16))
                            .foregroundColor(headerTextColor.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                case .shared:
                    Image(systemName: "person.2")
                        .font(.system(size: 48, weight: .ultraLight))
                        .foregroundColor(headerTextColor.opacity(0.3))
                    
                    VStack(spacing: 16) {
                        Text("No Shared Albums")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(headerTextColor.opacity(0.8))
                        
                        Text("Albums shared with you by other artists will appear here")
                            .font(.system(size: 16))
                            .foregroundColor(headerTextColor.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
            }
            
            Spacer()
            
            // Create Album Button (only for My Albums)
            if selectedTab == .myAlbums {
                Button(action: onCreateAlbum) {
                    Text("create album")
                        .font(.system(size: 11, weight: .ultraLight, design: .monospaced))
                        .foregroundColor(headerTextColor.opacity(0.4))
                        .tracking(1.0)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(buttonBackgroundColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(buttonBorderColor, lineWidth: 0.5)
                                )
                        )
                }
                .buttonStyle(MinimalButtonStyle())
            }
            
            Spacer()
        }
    }
    
    // MARK: - Add Album Button
    private var addAlbumButton: some View {
        Button(action: onCreateAlbum) {
            Text("add album")
                .font(.system(size: 11, weight: .ultraLight, design: .monospaced))
                .foregroundColor(headerTextColor.opacity(0.4))
                .tracking(1.0)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(buttonBackgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(buttonBorderColor, lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(MinimalButtonStyle())
        .padding(.top, 24)
    }
    
    // MARK: - MINIMAL SETTINGS ACCESS
    private var minimalSettingsAccess: some View {
        Button(action: {
            HapticFeedbackManager.shared.lightImpact()
            showingSettings = true
        }) {
            Text("settings")
                .font(.system(size: 11, weight: .ultraLight, design: .monospaced))
                .foregroundColor(headerTextColor.opacity(0.25))
                .tracking(1.0)
        }
        .buttonStyle(MinimalButtonStyle())
    }
    
    // MARK: - SHARE FUNCTION
    private func shareAlbum(_ album: Album) {
        print("🐛 DEBUG: shareAlbum called")
        print("🐛 DEBUG: Album title: \(album.title)")
        albumToShare = album
        showingShareSheet = true
        print("🐛 DEBUG: showingShareSheet set to: \(showingShareSheet)")
    }
    
    // MARK: - Color Helpers
    private var headerTextColor: Color {
        selectedService == .appleMusic ? .black : .white
    }
    
    private var buttonTextColor: Color {
        selectedService == .appleMusic ? .black : .white.opacity(0.8)
    }
    
    private var buttonBackgroundColor: Color {
        selectedService == .appleMusic ? .black.opacity(0.05) : .white.opacity(0.08)
    }
    
    private var buttonBorderColor: Color {
        selectedService == .appleMusic ? .black.opacity(0.1) : .white.opacity(0.15)
    }
    
    // MARK: - Load Shared Albums
    private func loadSharedAlbums() {
        // TODO: Implement actual shared albums loading from server/database
        // For now, we'll add some demo shared albums
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.smooth(duration: 0.3)) {
                sharedAlbums = createDemoSharedAlbums()
            }
        }
    }
    
    private func createDemoSharedAlbums() -> [Album] {
        // Demo shared albums - replace with actual server data
        return [
            Album(
                title: "Synthwave Dreams",
                artist: "NeonWave",
                songs: [
                    Song(title: "Electric Sunset", artist: "NeonWave", duration: 245),
                    Song(title: "Digital Highway", artist: "NeonWave", duration: 198),
                    Song(title: "Chrome Reflections", artist: "NeonWave", duration: 223)
                ],
                coverImage: nil,
                releaseDate: Date()
            ),
            Album(
                title: "Lo-Fi Mornings",
                artist: "ChillBeats",
                songs: [
                    Song(title: "Coffee Shop", artist: "ChillBeats", duration: 156),
                    Song(title: "Rainy Window", artist: "ChillBeats", duration: 189),
                    Song(title: "Study Session", artist: "ChillBeats", duration: 167)
                ],
                coverImage: nil,
                releaseDate: Date()
            )
        ]
    }
}

// MARK: - Service Background Components (alle bestehenden Components bleiben gleich)
struct SpotifyBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.11, green: 0.11, blue: 0.11),
                Color(red: 0.07, green: 0.07, blue: 0.07),
                Color(red: 0.04, green: 0.04, blue: 0.04)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct AppleMusicBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.white,
                Color(red: 0.98, green: 0.98, blue: 0.98),
                Color(red: 0.95, green: 0.95, blue: 0.97)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct AmazonMusicBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.12, green: 0.16, blue: 0.20),
                Color(red: 0.08, green: 0.12, blue: 0.16),
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct YouTubeMusicBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.05, green: 0.05, blue: 0.05),
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Service-Specific Artist Headers
struct AppleMusicArtistHeader: View {
    let artistName: String
    let albumCount: Int
    let profileManager: UserProfileManager
    
    var body: some View {
        VStack(spacing: 20) {
            Group {
                if let profileImage = profileManager.userProfile?.profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .frame(width: 150, height: 150)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 150, height: 150)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.3))
                        )
                }
            }
            
            VStack(spacing: 8) {
                Text(artistName)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.black)
                
                Text("Artist • \(albumCount) album\(albumCount == 1 ? "" : "s")")
                    .font(.system(size: 16))
                    .foregroundColor(.black.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct AmazonMusicArtistHeader: View {
    let artistName: String
    let albumCount: Int
    let profileManager: UserProfileManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Group {
                    if let profileImage = profileManager.userProfile?.profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.2, green: 0.24, blue: 0.28))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.3))
                            )
                    }
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(artistName)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                
                Text("\(albumCount) album\(albumCount == 1 ? "" : "s")")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct YouTubeMusicArtistHeader: View {
    let artistName: String
    let albumCount: Int
    let profileManager: UserProfileManager
    
    var body: some View {
        VStack(spacing: 24) {
            Group {
                if let profileImage = profileManager.userProfile?.profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
                        .frame(width: 140, height: 140)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 56))
                                .foregroundColor(.white.opacity(0.3))
                        )
                }
            }
            
            VStack(spacing: 8) {
                Text(artistName)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                
                Text("\(albumCount) album\(albumCount == 1 ? "" : "s")")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Albums Grid Components mit SHARE UNTERSTÜTZUNG
struct SpotifyAlbumsGrid: View {
    let albums: [Album]
    let onAlbumTap: (Album) -> Void
    let onShareAlbum: (Album) -> Void // NEU HINZUGEFÜGT
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Albums")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {}) {
                    Text("Show all")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
                }
            }
            
            VStack(spacing: 0) {
                ForEach(albums, id: \.id) { album in
                    SpotifyAlbumRow(
                        album: album,
                        onTap: { onAlbumTap(album) },
                        onShare: { onShareAlbum(album) } // SHARE HINZUGEFÜGT
                    )
                }
            }
        }
    }
}

struct SpotifyAlbumRow: View {
    let album: Album
    let onTap: () -> Void
    let onShare: () -> Void // NEU HINZUGEFÜGT
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    if let coverImage = album.coverImage {
                        Image(uiImage: coverImage)
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 0.18, green: 0.18, blue: 0.18))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundColor(.white.opacity(0.4))
                            )
                    }
                    
                    if isHovered || audioPlayer.currentSong?.id == album.songs.first?.id {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.black.opacity(0.6))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Button(action: {
                                    if let firstSong = album.songs.first {
                                        HapticFeedbackManager.shared.playPause()
                                        audioPlayer.play(song: firstSong)
                                    }
                                }) {
                                    Image(systemName: audioPlayer.currentSong?.id == album.songs.first?.id && audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 48, height: 48)
                                        .background(
                                            Circle()
                                                .fill(.black.opacity(0.8))
                                        )
                                }
                            )
                            .animation(.easeInOut(duration: 0.2), value: isHovered)
                    }
                }
                .onHover { hovering in
                    isHovered = hovering
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(album.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Text("2025")
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
                        
                        Text("•")
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
                        
                        Text("Album")
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
                    }
                }
                
                Spacer()
                
                // 3-DOTS MENU - JETZT IMMER SICHTBAR
                Menu {
                    Button("Share Album", action: onShare)
                    Button("Add to Library") { }
                    Button("Download") { }
                    Button("View Artist") { }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
                        // ENTFERNT: .opacity(isHovered ? 1.0 : 0.0)
                        // JETZT IMMER SICHTBAR
                }
                .buttonStyle(MinimalButtonStyle())
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.white.opacity(0.1) : Color.clear)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Simplified Other Grids mit SHARE
struct AppleMusicAlbumsGrid: View {
    let albums: [Album]
    let onAlbumTap: (Album) -> Void
    let onShareAlbum: (Album) -> Void // NEU HINZUGEFÜGT
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(albums, id: \.id) { album in
                HStack(spacing: 12) {
                    Button(action: { onAlbumTap(album) }) {
                        HStack(spacing: 12) {
                            if let coverImage = album.coverImage {
                                Image(uiImage: coverImage)
                                    .resizable()
                                    .aspectRatio(1, contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.gray.opacity(0.2))
                                    .frame(width: 60, height: 60)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(album.title)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.black)
                                Text(album.artist)
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // 3-DOTS MENU MIT SHARE
                    Menu {
                        Button("Share Album") { onShareAlbum(album) }
                        Button("Add to Library") { }
                        Button("View Artist") { }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.gray)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.gray.opacity(0.05))
                )
            }
        }
    }
}

struct AmazonMusicAlbumsGrid: View {
    let albums: [Album]
    let onAlbumTap: (Album) -> Void
    let onShareAlbum: (Album) -> Void // NEU HINZUGEFÜGT
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(albums, id: \.id) { album in
                HStack(spacing: 12) {
                    Button(action: { onAlbumTap(album) }) {
                        HStack(spacing: 12) {
                            if let coverImage = album.coverImage {
                                Image(uiImage: coverImage)
                                    .resizable()
                                    .aspectRatio(1, contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.white.opacity(0.1))
                                    .frame(width: 60, height: 60)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(album.title)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                Text(album.artist)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // 3-DOTS MENU MIT SHARE
                    Menu {
                        Button("Share Album") { onShareAlbum(album) }
                        Button("Download") { }
                        Button("Add to Playlist") { }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.05))
                )
            }
        }
    }
}

struct YouTubeMusicAlbumsGrid: View {
    let albums: [Album]
    let onAlbumTap: (Album) -> Void
    let onShareAlbum: (Album) -> Void // NEU HINZUGEFÜGT
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(albums, id: \.id) { album in
                HStack(spacing: 12) {
                    Button(action: { onAlbumTap(album) }) {
                        HStack(spacing: 12) {
                            if let coverImage = album.coverImage {
                                Image(uiImage: coverImage)
                                    .resizable()
                                    .aspectRatio(1, contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.white.opacity(0.1))
                                    .frame(width: 60, height: 60)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(album.title)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                Text(album.artist)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // 3-DOTS MENU MIT SHARE
                    Menu {
                        Button("Share Album") { onShareAlbum(album) }
                        Button("Add to Queue") { }
                        Button("Start Radio") { }
                        Button("View Artist") { }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.white.opacity(0.7))
                            .rotationEffect(.degrees(90))
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.05))
                )
            }
        }
    }
}

// MARK: - Minimal Service Selector
struct MinimalServiceSelector: View {
    @Binding var selectedService: StreamingService
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(StreamingService.allCases, id: \.self) { service in
                    Button(action: {
                        HapticFeedbackManager.shared.selection()
                        withAnimation(.smooth(duration: 0.3)) {
                            selectedService = service
                        }
                    }) {
                        ServiceSelectorButton(service: service, isSelected: selectedService == service)
                    }
                    .buttonStyle(MinimalButtonStyle())
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

struct ServiceSelectorButton: View {
    let service: StreamingService
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: service.iconName)
                .font(.system(size: 14, weight: .medium))
            
            Text(service.rawValue)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(isSelected ? .black : .white.opacity(0.6))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? .white : .white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.white.opacity(isSelected ? 0 : 0.2), lineWidth: 0.5)
                )
        )
    }
}
