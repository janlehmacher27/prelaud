//
//  AlbumsView.swift - ORIGINAL AUTHENTIC DESIGN RESTORED
//  prelaud
//
//  Restored original streaming platform design with proper layout
//

import SwiftUI

// MARK: - SharingRequest Model
struct SharingRequest: Identifiable {
    let id: UUID
    let shareId: String
    let fromUserId: String
    let fromUsername: String
    let toUserId: String
    let albumId: UUID
    let albumTitle: String
    let albumArtist: String
    let songCount: Int
    let permissions: SharePermissions
    let createdAt: Date
    var isRead: Bool
    var status: SharingRequestStatus
    
    init(id: UUID, shareId: String, fromUserId: String, fromUsername: String, toUserId: String, albumId: UUID, albumTitle: String, albumArtist: String, songCount: Int, permissions: SharePermissions, createdAt: Date, isRead: Bool, status: SharingRequestStatus) {
        self.id = id
        self.shareId = shareId
        self.fromUserId = fromUserId
        self.fromUsername = fromUsername
        self.toUserId = toUserId
        self.albumId = albumId
        self.albumTitle = albumTitle
        self.albumArtist = albumArtist
        self.songCount = songCount
        self.permissions = permissions
        self.createdAt = createdAt
        self.isRead = isRead
        self.status = status
    }
}

enum SharingRequestStatus: String, CaseIterable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
}

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
    @StateObject private var sharingManager = SupabaseAlbumSharingManager.shared
    @State private var selectedTab: AlbumTab = .myAlbums
    @State private var sharedAlbums: [Album] = []
    @State private var pendingRequests: [SharingRequest] = []
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
    
    private var headerTextColor: Color {
        selectedService == .appleMusic ? .black : .white
    }
    
    private var buttonBackgroundColor: Color {
        selectedService == .appleMusic ? .black.opacity(0.05) : .white.opacity(0.08)
    }
    
    private var buttonBorderColor: Color {
        selectedService == .appleMusic ? .black.opacity(0.1) : .white.opacity(0.15)
    }
    
    private var hasUnreadRequests: Bool {
        pendingRequests.contains { !$0.isRead }
    }
    
    // MARK: - Main Body
    var body: some View {
        ZStack {
            // Service-specific background
            serviceBackground
                .ignoresSafeArea()
                .animation(.smooth(duration: 0.6), value: selectedService)
            
            VStack(spacing: 0) {
                // Header with settings button
                VStack(spacing: 0) {
                    // Settings button
                    HStack {
                        Spacer()
                        Button(action: { showingSettings = true }) {
                            Text("settings")
                                .font(.system(size: 11, weight: .ultraLight, design: .monospaced))
                                .foregroundColor(headerTextColor.opacity(0.4))
                                .tracking(1.0)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    
                    // Main header
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
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                
                // Service selector
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
                .padding(.bottom, 20)
                
                // Tab selector
                HStack(spacing: 0) {
                    ForEach(AlbumTab.allCases, id: \.self) { tab in
                        TabButton(
                            tab: tab,
                            isSelected: selectedTab == tab,
                            textColor: headerTextColor,
                            hasNotification: tab == .shared && hasUnreadRequests,
                            onTap: { selectTab(tab) }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
                
                // Main content
                ScrollView {
                    VStack(spacing: 0) {
                        if selectedTab == .shared {
                            enhancedSharedContent
                        } else {
                            myAlbumsContent
                        }
                    }
                }
                
                Spacer()
            }
            
            // Mini player overlay
            miniPlayerOverlay
        }
        .onAppear(perform: setupView)
        .refreshable {
            await refreshData()
        }
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
    
    @ViewBuilder
    private var serviceBackground: some View {
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
    
    @ViewBuilder
    private var myAlbumsContent: some View {
        if albums.isEmpty {
            EmptyStateView(
                selectedTab: selectedTab,
                selectedService: selectedService,
                headerTextColor: headerTextColor,
                buttonBackgroundColor: buttonBackgroundColor,
                buttonBorderColor: buttonBorderColor,
                onCreateAlbum: onCreateAlbum
            )
        } else {
            VStack(spacing: 0) {
                // Albums section with title (Spotify style)
                VStack(alignment: .leading, spacing: 16) {
                    if selectedService == .spotify {
                        HStack {
                            Text("Albums")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Albums grid
                    authenticAlbumsGrid
                    
                    // Add album button centered below albums
                    HStack {
                        Spacer()
                        Button(action: onCreateAlbum) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(headerTextColor.opacity(0.5))
                                
                                Text("add album")
                                    .font(.system(size: 11, weight: .ultraLight, design: .monospaced))
                                    .foregroundColor(headerTextColor.opacity(0.4))
                                    .tracking(1.0)
                            }
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
                        .buttonStyle(PlainButtonStyle())
                        Spacer()
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 24)
                }
            }
        }
    }
    
    @ViewBuilder
    private var authenticAlbumsGrid: some View {
        switch selectedService {
        case .spotify:
            SpotifyAlbumsGrid(
                albums: albums,
                onAlbumTap: { selectAlbum($0) },
                onShareAlbum: { shareAlbum($0) }
            )
        case .appleMusic:
            ComingSoonView(service: "Apple Music")
        case .amazonMusic:
            ComingSoonView(service: "Amazon Music")
        case .youtubeMusic:
            ComingSoonView(service: "YouTube Music")
        }
    }
    
    private var enhancedSharedContent: some View {
        LazyVStack(alignment: .leading, spacing: 24) {
            if !pendingRequests.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Anfragen")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(headerTextColor)
                        
                        Spacer()
                        
                        let unreadCount = pendingRequests.filter { !$0.isRead }.count
                        if unreadCount > 0 {
                            Text("\(unreadCount)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.black)
                                .frame(width: 20, height: 20)
                                .background(
                                    Circle()
                                        .fill(Color(red: 1.0, green: 0.24, blue: 0.32))
                                )
                        }
                    }
                    
                    VStack(spacing: 0) {
                        ForEach(pendingRequests) { request in
                            SpotifyStyleSharingRequestRow(
                                request: request,
                                selectedService: selectedService,
                                onAccept: { acceptSharingRequest(request) },
                                onDecline: { declineSharingRequest(request) }
                            )
                        }
                    }
                }
                
                Rectangle()
                    .fill(headerTextColor.opacity(0.1))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
            }
            
            if !sharedAlbums.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Geteilte Alben")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(headerTextColor)
                        
                        Spacer()
                    }
                    
                    VStack(spacing: 0) {
                        ForEach(sharedAlbums, id: \.id) { album in
                            SpotifySharedAlbumRow(
                                album: album,
                                selectedService: selectedService,
                                onTap: { selectAlbum(album) },
                                onShare: { shareAlbum(album) }
                            )
                        }
                    }
                }
            }
            
            if pendingRequests.isEmpty && sharedAlbums.isEmpty {
                VStack(spacing: 24) {
                    Spacer(minLength: 60)
                    
                    Image(systemName: "person.2")
                        .font(.system(size: 48, weight: .ultraLight))
                        .foregroundColor(headerTextColor.opacity(0.3))
                    
                    VStack(spacing: 12) {
                        Text("Keine geteilten Alben")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(headerTextColor.opacity(0.8))
                        
                        Text("Alben, die andere mit dir teilen, erscheinen hier")
                            .font(.system(size: 16))
                            .foregroundColor(headerTextColor.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    Spacer(minLength: 60)
                }
            }
        }
    }
    
    private var miniPlayerOverlay: some View {
        VStack {
            Spacer()
            
            if let currentSong = audioPlayer.currentSong {
                AdaptiveMiniPlayer(service: selectedService)
                    .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))
                    .animation(Animation.spring(response: 0.6, dampingFraction: 0.8), value: audioPlayer.currentSong?.id)
                    .padding(EdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 20))
            }
        }
    }
    
    // MARK: - Actions
    
    private func setupView() {
        supabaseManager.migrateFromDropbox()
        
        if albums.isEmpty {
            albums = dataManager.savedAlbums
        }
        
        loadSharedAlbums()
        loadSharingRequests()
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
        
        if tab == .shared {
            markRequestsAsRead()
        }
    }
    
    private func selectAlbum(_ album: Album) {
        HapticFeedbackManager.shared.cardTap()
        withAnimation(.smooth(duration: 0.4)) {
            currentAlbum = album
        }
    }
    
    private func shareAlbum(_ album: Album) {
        HapticFeedbackManager.shared.lightImpact()
        albumToShare = album
        activeSheet = .share(album)
    }
    
    private func loadSharedAlbums() {
        Task {
            await MainActor.run {
                SupabaseAlbumSharingManager.shared.loadSharedAlbums()
            }
            
            try? await Task.sleep(for: .seconds(1))
            
            await MainActor.run {
                sharedAlbums = SupabaseAlbumSharingManager.shared.sharedWithMeAlbums
            }
        }
    }
    
    private func loadSharingRequests() {
        Task {
            await refreshSharingRequests()
        }
    }
    
    private func refreshSharingRequests() async {
        do {
            let requests = try await fetchPendingSharingRequests()
            await MainActor.run {
                pendingRequests = requests
            }
        } catch {
            print("❌ Failed to load sharing requests: \(error)")
        }
    }
    
    private func refreshSharedAlbums() async {
        await MainActor.run {
            SupabaseAlbumSharingManager.shared.loadSharedAlbums()
        }
        
        try? await Task.sleep(for: .seconds(1))
        
        await MainActor.run {
            sharedAlbums = SupabaseAlbumSharingManager.shared.sharedWithMeAlbums
        }
    }
    
    private func acceptSharingRequest(_ request: SharingRequest) {
        Task {
            do {
                try await approveSharingRequest(request)
                await refreshSharingRequests()
                await refreshSharedAlbums()
                
                HapticFeedbackManager.shared.success()
            } catch {
                HapticFeedbackManager.shared.error()
            }
        }
    }
    
    private func declineSharingRequest(_ request: SharingRequest) {
        Task {
            do {
                try await rejectSharingRequest(request)
                await refreshSharingRequests()
                
                HapticFeedbackManager.shared.lightImpact()
            } catch {
                HapticFeedbackManager.shared.error()
            }
        }
    }
    
    private func markRequestsAsRead() {
        Task {
            for request in pendingRequests.filter({ !$0.isRead }) {
                try? await markRequestAsRead(request.id)
            }
            await refreshSharingRequests()
        }
    }
    
    private func refreshData() async {
        await refreshSharingRequests()
        await refreshSharedAlbums()
    }
    
    private func handleHeaderTap() {
        #if DEBUG
        debugTapCount += 1
        if debugTapCount >= 5 {
            Task {
                await refreshData()
            }
        }
        #endif
    }
}

// MARK: - Supporting Views

struct TabButton: View {
    let tab: AlbumsView.AlbumTab
    let isSelected: Bool
    let textColor: Color
    let hasNotification: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(isSelected ? textColor.opacity(0.8) : textColor.opacity(0.25))
                        .tracking(1.0)
                    
                    if hasNotification {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.24, blue: 0.32))
                            .frame(width: 4, height: 4)
                            .offset(y: -2)
                    }
                }
                
                Rectangle()
                    .fill(isSelected ? textColor.opacity(0.6) : Color.clear)
                    .frame(height: 0.5)
                    .animation(.smooth(duration: 0.3), value: isSelected)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity)
    }
}

struct ServiceButton: View {
    let service: StreamingService
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(service.rawValue)
                .font(.system(size: 11, weight: .ultraLight, design: .monospaced))
                .foregroundColor(isSelected ? .black : .white.opacity(0.6))
                .tracking(1.0)
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
        .buttonStyle(PlainButtonStyle())
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
                    Image(systemName: "music.note")
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
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
        }
    }
}

// MARK: - Background Components

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

// MARK: - Coming Soon View
struct ComingSoonView: View {
    let service: String
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.white.opacity(0.3))
            
            VStack(spacing: 12) {
                Text("Work in Progress")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("\(service) view coming soon...")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 100)
    }
}

struct SpotifyAlbumsGrid: View {
    let albums: [Album]
    let onAlbumTap: (Album) -> Void
    let onShareAlbum: (Album) -> Void
    
    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(albums, id: \.id) { album in
                SpotifyAlbumRow(
                    album: album,
                    onTap: { onAlbumTap(album) },
                    onShare: { onShareAlbum(album) }
                )
            }
        }
        .padding(.horizontal, 0)
    }
}

struct SpotifyAlbumRow: View {
    let album: Album
    let onTap: () -> Void
    let onShare: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Large Square Album Cover (doppelt so groß)
                Group {
                    if let coverImage = album.coverImage {
                        Image(uiImage: coverImage)
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color(red: 0.25, green: 0.25, blue: 0.25))
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 35))
                                    .foregroundColor(.white.opacity(0.4))
                            )
                    }
                }
                .frame(width: 92, height: 92)
                .cornerRadius(4)
                
                // Album Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(album.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                    
                    Text(getAlbumYear(album))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // More Options Button
                Button(action: onShare) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 12)
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isPressed ? Color.white.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, perform: {}, onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        })
    }
    
    private func getAlbumYear(_ album: Album) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: album.releaseDate)
    }
}

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
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 20))
                            .foregroundColor(.gray.opacity(0.4))
                    )
            }
        }
    }
    
    private var albumInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(album.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .lineLimit(1)
            
            Text(album.artist)
                .font(.system(size: 14))
                .foregroundColor(.black.opacity(0.6))
                .lineLimit(1)
            
            Text("\(album.songs.count) songs")
                .font(.system(size: 12))
                .foregroundColor(.black.opacity(0.4))
                .lineLimit(1)
        }
    }
    
    private var shareMenu: some View {
        Button(action: onShare) {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AmazonMusicAlbumsGrid: View {
    let albums: [Album]
    let onAlbumTap: (Album) -> Void
    let onShareAlbum: (Album) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
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
        Button(action: onTap) {
            HStack(spacing: 16) {
                albumCover
                albumInfo
                Spacer()
                shareButton
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var albumCover: some View {
        Group {
            if let coverImage = album.coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.3))
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
            
            Text("\(album.songs.count) songs")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(1)
        }
    }
    
    private var shareButton: some View {
        Button(action: onShare) {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct YouTubeMusicAlbumsGrid: View {
    let albums: [Album]
    let onAlbumTap: (Album) -> Void
    let onShareAlbum: (Album) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
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
        Button(action: onTap) {
            HStack(spacing: 16) {
                albumCover
                albumInfo
                Spacer()
                shareButton
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var albumCover: some View {
        Group {
            if let coverImage = album.coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.3))
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
            
            Text("\(album.songs.count) songs")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(1)
        }
    }
    
    private var shareButton: some View {
        Button(action: onShare) {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Sharing Components

struct SpotifyStyleSharingRequestRow: View {
    let request: SharingRequest
    let selectedService: StreamingService
    let onAccept: () -> Void
    let onDecline: () -> Void
    @State private var isHovered = false
    
    private var textColor: Color {
        selectedService == .appleMusic ? .black : .white
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Album Cover Placeholder
            RoundedRectangle(cornerRadius: 6)
                .fill(selectedService == .appleMusic ? .gray.opacity(0.2) : Color(red: 0.18, green: 0.18, blue: 0.18))
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 20))
                        .foregroundColor(textColor.opacity(0.3))
                )
            
            // Request Info
            VStack(alignment: .leading, spacing: 4) {
                Text(request.albumTitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                
                Text("von @\(request.fromUsername)")
                    .font(.system(size: 14))
                    .foregroundColor(textColor.opacity(0.6))
                    .lineLimit(1)
                
                Text("\(request.songCount) songs")
                    .font(.system(size: 12))
                    .foregroundColor(textColor.opacity(0.4))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 12) {
                // Decline Button
                Button(action: onDecline) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textColor.opacity(0.6))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(selectedService == .appleMusic ? .black.opacity(0.08) : .white.opacity(0.08))
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Accept Button
                Button(action: onAccept) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(.white)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? (selectedService == .appleMusic ? .black.opacity(0.05) : .white.opacity(0.05)) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

struct SpotifySharedAlbumRow: View {
    let album: Album
    let selectedService: StreamingService
    let onTap: () -> Void
    let onShare: () -> Void
    @State private var isHovered = false
    
    private var textColor: Color {
        selectedService == .appleMusic ? .black : .white
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Album Cover
                Group {
                    if let coverImage = album.coverImage {
                        Image(uiImage: coverImage)
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(selectedService == .appleMusic ? .gray.opacity(0.2) : Color(red: 0.18, green: 0.18, blue: 0.18))
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 20))
                                    .foregroundColor(textColor.opacity(0.3))
                            )
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                
                // Album Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(album.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(textColor)
                        .lineLimit(1)
                    
                    if let ownerUsername = album.ownerUsername {
                        Text("von @\(ownerUsername)")
                            .font(.system(size: 14))
                            .foregroundColor(textColor.opacity(0.6))
                            .lineLimit(1)
                    }
                    
                    Text("\(album.songs.count) songs")
                        .font(.system(size: 12))
                        .foregroundColor(textColor.opacity(0.4))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Shared Icon
                Image(systemName: "person.2.fill")
                    .font(.system(size: 16))
                    .foregroundColor(textColor.opacity(0.4))
                
                // More Options
                Button(action: onShare) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20))
                        .foregroundColor(textColor.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? (selectedService == .appleMusic ? .black.opacity(0.05) : .white.opacity(0.05)) : Color.clear)
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

// MARK: - API Functions

@MainActor
func fetchPendingSharingRequests() async throws -> [SharingRequest] {
    guard let currentUser = UserProfileManager.shared.userProfile else {
        throw SharingError.notLoggedIn
    }
    
    let supabaseURL = "https://auzsunnwanzljiwdpzov.supabase.co"
    let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1enN1bm53YW56bGppd2Rwem92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIxMzIyNjksImV4cCI6MjA2NzcwODI2OX0.UmuoVT-7uXq5SMFr9duiurbE52Oe865w4ghYPkFwexE"
    
    let endpoint = "\(supabaseURL)/rest/v1/sharing_requests?to_user_id=eq.\(currentUser.id.uuidString)&status=eq.pending&select=*"
    guard let url = URL(string: endpoint) else {
        throw SharingError.invalidRequest
    }
    
    var request = URLRequest(url: url)
    request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
    request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        throw SharingError.fetchFailed
    }
    
    do {
        guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw SharingError.fetchFailed
        }
        
        var requests: [SharingRequest] = []
        
        for dict in jsonArray {
            guard let idString = dict["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let shareId = dict["share_id"] as? String,
                  let fromUserId = dict["from_user_id"] as? String,
                  let fromUsername = dict["from_username"] as? String,
                  let toUserId = dict["to_user_id"] as? String,
                  let albumIdString = dict["album_id"] as? String,
                  let albumId = UUID(uuidString: albumIdString),
                  let albumTitle = dict["album_title"] as? String,
                  let albumArtist = dict["album_artist"] as? String,
                  let songCount = dict["song_count"] as? Int,
                  let isRead = dict["is_read"] as? Bool,
                  let statusString = dict["status"] as? String else {
                continue
            }
            
            let status = SharingRequestStatus(rawValue: statusString) ?? .pending
            
            var finalDate = Date()
            if let createdAtString = dict["created_at"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let parsedDate = formatter.date(from: createdAtString) {
                    finalDate = parsedDate
                } else {
                    formatter.formatOptions = [.withInternetDateTime]
                    finalDate = formatter.date(from: createdAtString) ?? Date()
                }
            }
            
            var permissions = SharePermissions()
            if let permissionsDict = dict["permissions"] as? [String: Any] {
                let canListen = permissionsDict["canListen"] as? Bool ?? true
                let canDownload = permissionsDict["canDownload"] as? Bool ?? false
                var expiresAt: Date? = nil
                
                if let expiresAtString = permissionsDict["expiresAt"] as? String {
                    let expiresFormatter = ISO8601DateFormatter()
                    expiresFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    expiresAt = expiresFormatter.date(from: expiresAtString)
                }
                
                permissions = SharePermissions(canListen: canListen, canDownload: canDownload, expiresAt: expiresAt)
            }
            
            let request = SharingRequest(
                id: id,
                shareId: shareId,
                fromUserId: fromUserId,
                fromUsername: fromUsername,
                toUserId: toUserId,
                albumId: albumId,
                albumTitle: albumTitle,
                albumArtist: albumArtist,
                songCount: songCount,
                permissions: permissions,
                createdAt: finalDate,
                isRead: isRead,
                status: status
            )
            
            requests.append(request)
        }
        
        return requests
        
    } catch {
        throw SharingError.fetchFailed
    }
}

// FIXED: Simplified approveSharingRequest function
@MainActor
func approveSharingRequest(_ request: SharingRequest) async throws {
    let supabaseURL = "https://auzsunnwanzljiwdpzov.supabase.co"
    let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1enN1bm53YW56bGppd2Rwem92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIxMzIyNjksImV4cCI6MjA2NzcwODI2OX0.UmuoVT-7uXq5SMFr9duiurbE52Oe865w4ghYPkFwexE"
    
    guard let currentUser = UserProfileManager.shared.userProfile else {
        throw SharingError.notLoggedIn
    }
    
    let requestEndpoint = "\(supabaseURL)/rest/v1/sharing_requests?id=eq.\(request.id.uuidString)"
    guard let requestUrl = URL(string: requestEndpoint) else {
        throw SharingError.invalidRequest
    }
    
    var requestUpdate = URLRequest(url: requestUrl)
    requestUpdate.httpMethod = "PATCH"
    requestUpdate.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
    requestUpdate.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
    requestUpdate.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let requestUpdateData: [String: Any] = [
        "status": "approved",
        "is_read": true
    ]
    
    requestUpdate.httpBody = try JSONSerialization.data(withJSONObject: requestUpdateData)
    
    let (_, requestResponse) = try await URLSession.shared.data(for: requestUpdate)
    guard let httpRequestResponse = requestResponse as? HTTPURLResponse,
          httpRequestResponse.statusCode == 204 else {
        throw SharingError.networkError
    }
    
    // Create shared album locally
    let sharedAlbum = Album(
        title: request.albumTitle,
        artist: request.albumArtist,
        songs: [],
        coverImage: nil,
        releaseDate: Date()
    )
    
    var mutableSharedAlbum = sharedAlbum
    mutableSharedAlbum.shareId = request.shareId
    mutableSharedAlbum.ownerId = request.fromUserId
    mutableSharedAlbum.ownerUsername = request.fromUsername
    
    let albumData = EncodableAlbum(
        from: mutableSharedAlbum,
        shareId: request.shareId,
        ownerId: request.fromUserId,
        ownerUsername: request.fromUsername
    )
    
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    
    if let encoded = try? encoder.encode(albumData) {
        UserDefaults.standard.set(encoded, forKey: "SharedAlbumData_\(request.shareId)")
    }
}

@MainActor
func rejectSharingRequest(_ request: SharingRequest) async throws {
    let supabaseURL = "https://auzsunnwanzljiwdpzov.supabase.co"
    let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1enN1bm53YW56bGppd2Rwem92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIxMzIyNjksImV4cCI6MjA2NzcwODI2OX0.UmuoVT-7uXq5SMFr9duiurbE52Oe865w4ghYPkFwexE"
    
    let endpoint = "\(supabaseURL)/rest/v1/sharing_requests?id=eq.\(request.id.uuidString)"
    guard let url = URL(string: endpoint) else {
        throw SharingError.invalidRequest
    }
    
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "PATCH"
    urlRequest.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
    urlRequest.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let updateData: [String: Any] = ["status": "rejected", "is_read": true]
    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: updateData)
    
    let (_, response) = try await URLSession.shared.data(for: urlRequest)
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 else {
        throw SharingError.networkError
    }
}

@MainActor
func markRequestAsRead(_ requestId: UUID) async throws {
    let supabaseURL = "https://auzsunnwanzljiwdpzov.supabase.co"
    let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1enN1bm53YW56bGppd2Rwem92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIxMzIyNjksImV4cCI6MjA2NzcwODI2OX0.UmuoVT-7uXq5SMFr9duiurbE52Oe865w4ghYPkFwexE"
    
    let endpoint = "\(supabaseURL)/rest/v1/sharing_requests?id=eq.\(requestId.uuidString)"
    guard let url = URL(string: endpoint) else {
        throw SharingError.invalidRequest
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "PATCH"
    request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
    request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let updateData: [String: Any] = ["is_read": true]
    request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
    
    let (_, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 else {
        throw SharingError.networkError
    }
}

// MARK: - Date Extension for ISO8601
extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}
