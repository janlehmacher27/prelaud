//
//  AlbumsView.swift - OPTIMIZED VERSION WITH WORKING SHARE SHEET
//  prelaud
//
//  Complete rewrite with proper sheet management and clean architecture
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
    
    // OPTIMIZED: Single sheet management with enum
    @State private var activeSheet: SheetType?
    @State private var albumToShare: Album?
    
    #if DEBUG
    @State private var debugTapCount = 0
    #endif
    
    // MARK: - Enums
    enum AlbumTab: String, CaseIterable {
        case myAlbums = "my albums"
        case shared = "shared"
    }
    
    enum SheetType: Identifiable {
        case settings
        case share(Album)
        
        var id: String {
            switch self {
            case .settings: return "settings"
            case .share(let album): return "share_\(album.id)"
            }
        }
    }
    
    // MARK: - Computed Properties
    private var artistName: String {
        profileManager.displayName
    }
    
    private var currentAlbums: [Album] {
        switch selectedTab {
        case .myAlbums: return albums
        case .shared: return sharedAlbums
        }
    }
    
    private var headerTextColor: Color {
        selectedService == .appleMusic ? .black : .white
    }
    
    private var buttonBackgroundColor: Color {
        selectedService == .appleMusic ? .black.opacity(0.05) : .white.opacity(0.08)
    }
    
    private var buttonBorderColor: Color {
        selectedService == .appleMusic ? .black.opacity(0.1) : .white.opacity(0.15)
    }
    
    // MARK: - Main Body
    var body: some View {
        ZStack {
            // Service-specific background
            serviceBackground
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    headerSection
                        .padding(.top, 60)
                        .padding(.bottom, 32)
                    
                    // Service Selector
                    serviceSelector
                        .padding(.bottom, 24)
                    
                    // Tab Selector
                    tabSelector
                        .padding(.bottom, 40)
                    
                    // Main Content
                    mainContent
                    
                    // Settings Access
                    settingsAccess
                        .padding(.top, 40)
                        .padding(.bottom, audioPlayer.currentSong != nil ? 140 : 60)
                }
                .padding(.horizontal, 24)
            }
            
            // Mini Player Overlay
            miniPlayerOverlay
        }
        .onAppear(perform: setupView)
        // OPTIMIZED: Single sheet modifier with enum-based management
        .sheet(item: $activeSheet) { sheetType in
            switch sheetType {
            case .settings:
                SettingsView()
            case .share(let album):
                AlbumShareSheet(album: album)
            }
        }
    }
    
    // MARK: - View Components
    
    private var serviceBackground: some View {
        Group {
            switch selectedService {
            case .spotify: SpotifyBackground()
            case .appleMusic: AppleMusicBackground()
            case .amazonMusic: AmazonMusicBackground()
            case .youtubeMusic: YouTubeMusicBackground()
            }
        }
        .ignoresSafeArea()
        .animation(.smooth(duration: 0.6), value: selectedService)
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                Text("pre")
                    .font(.system(size: 28, weight: .thin, design: .monospaced))
                    .foregroundColor(headerTextColor.opacity(0.9))
                    .tracking(2.0)
                    .onTapGesture(perform: handleHeaderTap)
                
                Text("laud")
                    .font(.system(size: 28, weight: .thin, design: .monospaced))
                    .foregroundColor(headerTextColor.opacity(0.5))
                    .tracking(2.0)
            }
            
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
    
    private var serviceSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(StreamingService.allCases, id: \.self) { service in
                    ServiceButton(
                        service: service,
                        isSelected: selectedService == service,
                        onTap: { selectService(service) }
                    )
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(AlbumTab.allCases, id: \.self) { tab in
                TabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    textColor: headerTextColor,
                    onTap: { selectTab(tab) }
                )
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var mainContent: some View {
        Group {
            if currentAlbums.isEmpty {
                EmptyStateView(
                    selectedTab: selectedTab,
                    selectedService: selectedService,
                    headerTextColor: headerTextColor,
                    buttonBackgroundColor: buttonBackgroundColor,
                    buttonBorderColor: buttonBorderColor,
                    onCreateAlbum: onCreateAlbum
                )
            } else {
                VStack(spacing: 24) {
                    if selectedTab == .myAlbums {
                        artistHeaderSection
                    }
                    
                    albumsGridSection
                    
                    if selectedTab == .myAlbums {
                        addAlbumButton
                    }
                }
            }
        }
    }
    
    private var artistHeaderSection: some View {
        Group {
            switch selectedService {
            case .spotify: EmptyView()
            case .appleMusic: AppleMusicArtistHeader(artistName: artistName, albumCount: albums.count, profileManager: profileManager)
            case .amazonMusic: AmazonMusicArtistHeader(artistName: artistName, albumCount: albums.count, profileManager: profileManager)
            case .youtubeMusic: YouTubeMusicArtistHeader(artistName: artistName, albumCount: albums.count, profileManager: profileManager)
            }
        }
        .animation(.smooth(duration: 0.6), value: selectedService)
    }
    
    private var albumsGridSection: some View {
        Group {
            switch selectedService {
            case .spotify:
                SpotifyAlbumsGrid(
                    albums: currentAlbums,
                    onAlbumTap: selectAlbum,
                    onShareAlbum: shareAlbum
                )
            case .appleMusic:
                AppleMusicAlbumsGrid(
                    albums: currentAlbums,
                    onAlbumTap: selectAlbum,
                    onShareAlbum: shareAlbum
                )
            case .amazonMusic:
                AmazonMusicAlbumsGrid(
                    albums: currentAlbums,
                    onAlbumTap: selectAlbum,
                    onShareAlbum: shareAlbum
                )
            case .youtubeMusic:
                YouTubeMusicAlbumsGrid(
                    albums: currentAlbums,
                    onAlbumTap: selectAlbum,
                    onShareAlbum: shareAlbum
                )
            }
        }
        .animation(.smooth(duration: 0.6), value: selectedService)
        .animation(.smooth(duration: 0.3), value: selectedTab)
    }
    
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
    
    private var settingsAccess: some View {
        Button(action: showSettings) {
            Text("settings")
                .font(.system(size: 11, weight: .ultraLight, design: .monospaced))
                .foregroundColor(headerTextColor.opacity(0.25))
                .tracking(1.0)
        }
        .buttonStyle(MinimalButtonStyle())
    }
    
    private var miniPlayerOverlay: some View {
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
    
    // MARK: - Actions
    
    private func setupView() {
        #if DEBUG
        debugSupabaseConnection()
        #endif
        
        supabaseManager.migrateFromDropbox()
        
        if albums.isEmpty {
            albums = dataManager.savedAlbums
        }
        loadSharedAlbums()
    }
    
    private func selectService(_ service: StreamingService) {
        HapticFeedbackManager.shared.selection()
        withAnimation(.smooth(duration: 0.3)) {
            selectedService = service
        }
    }
    
    private func selectTab(_ tab: AlbumTab) {
        HapticFeedbackManager.shared.selection()
        withAnimation(.smooth(duration: 0.3)) {
            selectedTab = tab
        }
    }
    
    private func selectAlbum(_ album: Album) {
        HapticFeedbackManager.shared.cardTap()
        withAnimation(.smooth(duration: 0.4)) {
            currentAlbum = album
        }
    }
    
    // OPTIMIZED: Clean share function
    private func shareAlbum(_ album: Album) {
        print("📤 Sharing album: \(album.title)")
        HapticFeedbackManager.shared.lightImpact()
        
        albumToShare = album
        activeSheet = .share(album)
    }
    
    private func showSettings() {
        HapticFeedbackManager.shared.lightImpact()
        activeSheet = .settings
    }
    
    private func handleHeaderTap() {
        #if DEBUG
        debugTapCount += 1
        if debugTapCount >= 5 {
            HapticFeedbackManager.shared.heavyImpact()
            UserProfileManager.shared.resetProfileForFirstTimeSetup()
            debugTapCount = 0
        }
        #endif
    }
    
    private func loadSharedAlbums() {
        // TODO: Implement actual shared albums loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.smooth(duration: 0.3)) {
                sharedAlbums = createDemoSharedAlbums()
            }
        }
    }
    
    private func createDemoSharedAlbums() -> [Album] {
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

// MARK: - Supporting Views

struct ServiceButton: View {
    let service: StreamingService
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
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
        .buttonStyle(MinimalButtonStyle())
    }
}

struct TabButton: View {
    let tab: AlbumsView.AlbumTab
    let isSelected: Bool
    let textColor: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(tab.rawValue)
                    .font(.system(size: 11, weight: .ultraLight, design: .monospaced))
                    .foregroundColor(isSelected ? textColor.opacity(0.8) : textColor.opacity(0.25))
                    .tracking(1.0)
                
                Rectangle()
                    .fill(isSelected ? textColor.opacity(0.6) : Color.clear)
                    .frame(height: 0.5)
                    .animation(.smooth(duration: 0.3), value: isSelected)
            }
        }
        .buttonStyle(MinimalButtonStyle())
        .frame(maxWidth: .infinity)
    }
}

struct EmptyStateView: View {
    let selectedTab: AlbumsView.AlbumTab
    let selectedService: StreamingService
    let headerTextColor: Color
    let buttonBackgroundColor: Color
    let buttonBorderColor: Color
    let onCreateAlbum: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Group {
                switch selectedTab {
                case .myAlbums:
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
}

// MARK: - Background Components (unchanged from original)

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

// MARK: - Artist Headers (unchanged from original)

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

// MARK: - Albums Grid Components (optimized with better share integration)

struct SpotifyAlbumsGrid: View {
    let albums: [Album]
    let onAlbumTap: (Album) -> Void
    let onShareAlbum: (Album) -> Void
    
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
                        onShare: { onShareAlbum(album) }
                    )
                }
            }
        }
    }
}

struct SpotifyAlbumRow: View {
    let album: Album
    let onTap: () -> Void
    let onShare: () -> Void
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                albumCoverSection
                
                albumInfoSection
                
                Spacer()
                
                shareMenuSection
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
    
    private var albumCoverSection: some View {
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
                playButtonOverlay
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var playButtonOverlay: some View {
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
    
    private var albumInfoSection: some View {
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
    }
    
    private var shareMenuSection: some View {
        Menu {
            Button("Share Album") {
                print("📤 Share menu triggered for: \(album.title)")
                onShare()
            }
            Button("Add to Library") { }
            Button("Download") { }
            Button("View Artist") { }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
        }
        .buttonStyle(MinimalButtonStyle())
    }
}

// MARK: - Other Service Album Grids (Optimized)

struct AppleMusicAlbumsGrid: View {
    let albums: [Album]
    let onAlbumTap: (Album) -> Void
    let onShareAlbum: (Album) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(albums, id: \.id) { album in
                AppleMusicAlbumRow(
                    album: album,
                    onTap: { onAlbumTap(album) },
                    onShare: { onShareAlbum(album) }
                )
            }
        }
    }
}

struct AppleMusicAlbumRow: View {
    let album: Album
    let onTap: () -> Void
    let onShare: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    albumCover
                    albumInfo
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            shareMenu
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.gray.opacity(0.05))
        )
    }
    
    private var albumCover: some View {
        Group {
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
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.gray.opacity(0.5))
                    )
            }
        }
    }
    
    private var albumInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(album.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
                .lineLimit(1)
            
            Text(album.artist)
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .lineLimit(1)
        }
    }
    
    private var shareMenu: some View {
        Menu {
            Button("Share Album") { onShare() }
            Button("Add to Library") { }
            Button("View Artist") { }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundColor(.gray)
        }
        .buttonStyle(MinimalButtonStyle())
    }
}

struct AmazonMusicAlbumsGrid: View {
    let albums: [Album]
    let onAlbumTap: (Album) -> Void
    let onShareAlbum: (Album) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(albums, id: \.id) { album in
                AmazonMusicAlbumRow(
                    album: album,
                    onTap: { onAlbumTap(album) },
                    onShare: { onShareAlbum(album) }
                )
            }
        }
    }
}

struct AmazonMusicAlbumRow: View {
    let album: Album
    let onTap: () -> Void
    let onShare: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    albumCover
                    albumInfo
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            shareMenu
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.05))
        )
    }
    
    private var albumCover: some View {
        Group {
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
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.white.opacity(0.4))
                    )
            }
        }
    }
    
    private var albumInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(album.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(album.artist)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
        }
    }
    
    private var shareMenu: some View {
        Menu {
            Button("Share Album") { onShare() }
            Button("Download") { }
            Button("Add to Playlist") { }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundColor(.white.opacity(0.7))
        }
        .buttonStyle(MinimalButtonStyle())
    }
}

struct YouTubeMusicAlbumsGrid: View {
    let albums: [Album]
    let onAlbumTap: (Album) -> Void
    let onShareAlbum: (Album) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(albums, id: \.id) { album in
                YouTubeMusicAlbumRow(
                    album: album,
                    onTap: { onAlbumTap(album) },
                    onShare: { onShareAlbum(album) }
                )
            }
        }
    }
}

struct YouTubeMusicAlbumRow: View {
    let album: Album
    let onTap: () -> Void
    let onShare: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    albumCover
                    albumInfo
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            shareMenu
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.05))
        )
    }
    
    private var albumCover: some View {
        Group {
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
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.white.opacity(0.4))
                    )
            }
        }
    }
    
    private var albumInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(album.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(album.artist)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
        }
    }
    
    private var shareMenu: some View {
        Menu {
            Button("Share Album") { onShare() }
            Button("Add to Queue") { }
            Button("Start Radio") { }
            Button("View Artist") { }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundColor(.white.opacity(0.7))
                .rotationEffect(.degrees(90))
        }
        .buttonStyle(MinimalButtonStyle())
    }
}
