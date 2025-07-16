//
//  AlbumsView.swift - FIXED APPLE MUSIC TEXT COLORS
//  prelaud
//
//  Fixed header text and button colors for Apple Music service
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
    @State private var showingDeleteAlert = false
    @State private var albumToDelete: Album?
    
    // NEW: Album Edit States
    @State private var showingEditSheet = false
    @State private var albumToEdit: Album?
    
    @State private var debugTapCount = 0
    
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
            case .share(let album): return "share-\(album.id)"
            }
        }
    }
    
    // FIXED: Corrected color logic for Apple Music
    private var headerTextColor: Color {
        switch selectedService {
        case .spotify:
            return .white.opacity(0.6)
        case .appleMusic:
            return .black.opacity(0.6)  // Dark text for Apple Music
        case .amazonMusic:
            return .white.opacity(0.6)
        case .youtubeMusic:
            return .white.opacity(0.6)
        }
    }
    
    // NEW: Icon colors for service buttons
    private var serviceIconColor: Color {
        switch selectedService {
        case .spotify:
            return .white
        case .appleMusic:
            return .black  // Dark icons for Apple Music
        case .amazonMusic:
            return .white
        case .youtubeMusic:
            return .white
        }
    }
    
    // NEW: Tab text colors
    private var tabTextColor: Color {
        switch selectedService {
        case .spotify:
            return .white
        case .appleMusic:
            return .black  // Dark text for Apple Music tabs
        case .amazonMusic:
            return .white
        case .youtubeMusic:
            return .white
        }
    }
    
    private var hasUnreadRequests: Bool {
        pendingRequests.contains { !$0.isRead }
    }
    
    var body: some View {
        ZStack {
            // Dynamic Background
            backgroundForService
            
            VStack(spacing: 0) {
                // Header
                headerSection
                    .padding(.top, 50)
                    .padding(.bottom, 24)
                
                // Service selector
                streamingServiceSelector
                    .padding(.bottom, 28)
                
                // Tab selector
                VStack(spacing: 0) {
                    HStack(spacing: 40) {
                        ForEach(AlbumTab.allCases, id: \.self) { tab in
                            TabButton(
                                tab: tab,
                                isSelected: selectedTab == tab,
                                textColor: tabTextColor,  // FIXED: Use tab-specific color
                                hasNotification: tab == .shared && hasUnreadRequests,
                                onTap: { selectTab(tab) }
                            )
                        }
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
        .sheet(isPresented: $showingEditSheet) {
            AlbumEditView(
                album: Binding(
                    get: { albumToEdit ?? Album(title: "", artist: "", songs: [], coverImage: nil, releaseDate: Date()) },
                    set: { updatedAlbum in
                        // Update the album in the albums array
                        if let index = albums.firstIndex(where: { $0.id == updatedAlbum.id }) {
                            albums[index] = updatedAlbum
                        }
                        self.albumToEdit = updatedAlbum
                    }
                ),
                onSave: { updatedAlbum in
                    // Save to persistent storage
                    dataManager.saveAlbum(updatedAlbum)
                    
                    // Update the albums array
                    if let index = albums.firstIndex(where: { $0.id == updatedAlbum.id }) {
                        albums[index] = updatedAlbum
                    }
                    
                    print("✅ Album saved: \(updatedAlbum.title)")
                },
                onDelete: {
                    // Delete from albums array and storage
                    if let albumToEdit = albumToEdit {
                        confirmDeleteAlbum(albumToEdit)
                    }
                }
            )
        }
        .alert("Delete Album", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let album = albumToDelete {
                    confirmDeleteAlbum(album)
                }
            }
        } message: {
            if let album = albumToDelete {
                Text("Are you sure you want to delete \"\(album.title)\"? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Background For Service
    @ViewBuilder
    private var backgroundForService: some View {
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
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Text("prelaud")
                .font(.system(size: 11, weight: .light, design: .monospaced))
                .foregroundColor(headerTextColor)
                .tracking(3.0)
                .onTapGesture {
                    handleHeaderTap()
                }
            
            Spacer()
            
            Button(action: {
                HapticFeedbackManager.shared.lightImpact()
                activeSheet = .settings
            }) {
                Image(systemName: "person.circle")
                    .font(.system(size: 20))
                    .foregroundColor(headerTextColor)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Streaming Service Selector
    private var streamingServiceSelector: some View {
        HStack(spacing: 32) {
            ForEach(StreamingService.allCases, id: \.self) { service in
                ServiceButton(
                    service: service,
                    isSelected: selectedService == service,
                    selectedServiceColor: serviceIconColor,  // FIXED: Pass service-specific color
                    onTap: { selectService(service) }
                )
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - My Albums Content
    private var myAlbumsContent: some View {
        VStack(spacing: 24) {
            if selectedService == .spotify {
                spotifyMyAlbumsContent
            } else {
                otherServiceContent
            }
        }
        .padding(.bottom, 100)
    }
    
    private var spotifyMyAlbumsContent: some View {
        VStack(spacing: 24) {
            // CREATE ALBUM BUTTON
            Button(action: {
                HapticFeedbackManager.shared.cardTap()
                onCreateAlbum()
            }) {
                VStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.02))
                        .frame(height: 120)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 32, weight: .ultraLight))
                                    .foregroundColor(.white.opacity(0.3))
                                
                                Text("create album")
                                    .font(.system(size: 11, weight: .light, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.3))
                                    .tracking(1.0)
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.05), lineWidth: 1)
                        )
                }
            }
            .buttonStyle(MinimalButtonStyle())
            .padding(.horizontal, 20)
            
            // ALBUMS GRID
            if !albums.isEmpty {
                SpotifyAlbumsGrid(
                    albums: albums,
                    onAlbumTap: selectAlbum,
                    onShareAlbum: shareAlbum,
                    onDeleteAlbum: deleteAlbum,
                    onEditAlbum: editAlbum
                )
                .padding(.top, 20)
            }
        }
    }
    
    private var otherServiceContent: some View {
        VStack {
            if !albums.isEmpty {
                LazyVStack(spacing: 16) {
                    ForEach(albums, id: \.id) { album in
                        UniversalAlbumRow(
                            album: album,
                            selectedService: selectedService,
                            onTap: { selectAlbum(album) },
                            onShare: { shareAlbum(album) }
                        )
                    }
                }
                .padding(.horizontal, 20)
            } else {
                emptyStateView
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 60)
            
            Image(systemName: "music.note")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundColor(headerTextColor.opacity(0.3))
            
            VStack(spacing: 12) {
                Text("Keine Alben")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(headerTextColor.opacity(0.8))
                
                Text("Erstelle dein erstes Album")
                    .font(.system(size: 16))
                    .foregroundColor(headerTextColor.opacity(0.5))
            }
            
            // CREATE BUTTON
            Button(action: {
                HapticFeedbackManager.shared.cardTap()
                onCreateAlbum()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    
                    Text("Album erstellen")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(selectedService == .appleMusic ? .white : .black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(selectedService == .appleMusic ? .black.opacity(0.8) : .white.opacity(0.9))
                )
            }
            .buttonStyle(MinimalButtonStyle())
            .padding(.top, 20)
            
            Spacer(minLength: 60)
        }
    }
    
    // MARK: - Enhanced Shared Content
    private var enhancedSharedContent: some View {
        VStack(spacing: 32) {
            // Pending requests section
            if !pendingRequests.isEmpty {
                VStack(spacing: 16) {
                    HStack {
                        Text("Pending Requests")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(headerTextColor.opacity(0.9))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    LazyVStack(spacing: 12) {
                        ForEach(pendingRequests) { request in
                            SpotifyStyleSharingRequestRow(
                                request: request,
                                selectedService: selectedService,
                                onAccept: { acceptSharingRequest(request) },
                                onDecline: { declineSharingRequest(request) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            // Shared albums section
            if !sharedAlbums.isEmpty {
                VStack(spacing: 16) {
                    HStack {
                        Text("Shared with me")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(headerTextColor.opacity(0.9))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    LazyVStack(spacing: 16) {
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
    
    // MARK: - Actions (unchanged methods)
    
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
    
    private func deleteAlbum(_ album: Album) {
        HapticFeedbackManager.shared.lightImpact()
        albumToDelete = album
        showingDeleteAlert = true
    }
    
    private func confirmDeleteAlbum(_ album: Album) {
        HapticFeedbackManager.shared.mediumImpact()
        
        // Remove from albums array with animation
        withAnimation(.smooth(duration: 0.3)) {
            albums.removeAll { $0.id == album.id }
        }
        
        // Remove from persistent storage
        dataManager.deleteAlbum(album)
        
        // Reset state
        albumToDelete = nil
        albumToEdit = nil
        showingEditSheet = false
        
        HapticFeedbackManager.shared.success()
        print("🗑️ Album deleted: \(album.title)")
    }
    
    private func editAlbum(_ album: Album) {
        HapticFeedbackManager.shared.lightImpact()
        albumToEdit = album
        showingEditSheet = true
        print("✏️ Edit album: \(album.title)")
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
                // NEW: Debug sharing requests table
                await debugSharingRequestsTable()
            }
        }
        #endif
    }
}

// MARK: - Enhanced Spotify Albums Grid with Context Menu
struct SpotifyAlbumsGrid: View {
    let albums: [Album]
    let onAlbumTap: (Album) -> Void
    let onShareAlbum: (Album) -> Void
    let onDeleteAlbum: (Album) -> Void
    let onEditAlbum: (Album) -> Void
    
    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(albums, id: \.id) { album in
                SpotifyAlbumRowWithContextMenu(
                    album: album,
                    onTap: { onAlbumTap(album) },
                    onShare: { onShareAlbum(album) },
                    onDelete: { onDeleteAlbum(album) },
                    onEdit: { onEditAlbum(album) }
                )
            }
        }
        .padding(.horizontal, 0)
    }
}

// MARK: - Enhanced Spotify Album Row with Context Menu
struct SpotifyAlbumRowWithContextMenu: View {
    let album: Album
    let onTap: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Large Square Album Cover
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
        .contextMenu {
            Button(action: onTap) {
                Label("Play Album", systemImage: "play.fill")
            }
            
            Button(action: onShare) {
                Label("Share Album", systemImage: "square.and.arrow.up")
            }
            
            Button(action: {
                HapticFeedbackManager.shared.lightImpact()
                print("📋 Add to playlist: \(album.title)")
            }) {
                Label("Add to Playlist", systemImage: "plus.circle")
            }
            
            Button(action: {
                HapticFeedbackManager.shared.lightImpact()
                print("⬇️ Download: \(album.title)")
            }) {
                Label("Download", systemImage: "arrow.down.circle")
            }
            
            Divider()
            
            Button(action: onEdit) {
                Label("Edit Album", systemImage: "pencil")
            }
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete Album", systemImage: "trash")
            }
        }
    }
    
    private func getAlbumYear(_ album: Album) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: album.releaseDate)
    }
}

// MARK: - FIXED Tab Button with proper color handling
struct TabButton: View {
    let tab: AlbumsView.AlbumTab
    let isSelected: Bool
    let textColor: Color  // Now receives the correct color from parent
    let hasNotification: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(isSelected ? textColor.opacity(0.9) : textColor.opacity(0.5))  // FIXED: Use passed textColor
                        .tracking(0.5)
                    
                    if hasNotification {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                    }
                }
                
                Rectangle()
                    .fill(isSelected ? textColor.opacity(0.8) : .clear)  // FIXED: Use passed textColor
                    .frame(height: 1)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - FIXED Service Button with proper color handling
struct ServiceButton: View {
    let service: StreamingService
    let isSelected: Bool
    let selectedServiceColor: Color  // NEW: Pass the correct color from parent
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: service.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? selectedServiceColor.opacity(0.9) : selectedServiceColor.opacity(0.3))  // FIXED: Use passed color
                
                Text(service.rawValue)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(isSelected ? selectedServiceColor.opacity(0.7) : selectedServiceColor.opacity(0.3))  // FIXED: Use passed color
                    .tracking(0.5)
            }
        }
        .buttonStyle(MinimalButtonStyle())
    }
}

// MARK: - Background Views (unchanged)
struct SpotifyBackground: View {
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

struct AppleMusicBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
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

// MARK: - Sharing Components (unchanged)

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
                Text("@\(request.fromUsername)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                
                Text("möchte \"\(request.albumTitle)\" teilen")
                    .font(.system(size: 14))
                    .foregroundColor(textColor.opacity(0.6))
                    .lineLimit(2)
                
                Text("\(request.songCount) songs")
                    .font(.system(size: 12))
                    .foregroundColor(textColor.opacity(0.4))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 8) {
                Button("Accept") {
                    HapticFeedbackManager.shared.success()
                    onAccept()
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 60, height: 28)
                .background(Color.green)
                .cornerRadius(14)
                
                Button("Decline") {
                    HapticFeedbackManager.shared.lightImpact()
                    onDecline()
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(textColor.opacity(0.6))
                .frame(width: 60, height: 28)
                .background(textColor.opacity(0.1))
                .cornerRadius(14)
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

struct UniversalAlbumRow: View {
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
                    
                    Text(album.artist)
                        .font(.system(size: 14))
                        .foregroundColor(textColor.opacity(0.6))
                        .lineLimit(1)
                    
                    Text("\(album.songs.count) songs")
                        .font(.system(size: 12))
                        .foregroundColor(textColor.opacity(0.4))
                        .lineLimit(1)
                }
                
                Spacer()
                
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

// MARK: - IMPLEMENTED Functions for Sharing Requests
func fetchPendingSharingRequests() async throws -> [SharingRequest] {
    print("🔍 Fetching pending sharing requests...")
    
    guard let currentUser = UserProfileManager.shared.userProfile else {
        print("❌ No current user found")
        return []
    }
    
    let supabaseURL = "https://auzsunnwanzljiwdpzov.supabase.co"
    let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1enN1bm53YW56bGppd2Rwem92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIxMzIyNjksImV4cCI6MjA2NzcwODI2OX0.UmuoVT-7uXq5SMFr9duiurbE52Oe865w4ghYPkFwexE"
    
    // Fetch sharing requests for current user
    let endpoint = "\(supabaseURL)/rest/v1/sharing_requests?to_user_id=eq.\(currentUser.id.uuidString)&status=eq.pending&select=*"
    guard let url = URL(string: endpoint) else {
        throw SharingError.invalidRequest
    }
    
    var request = URLRequest(url: url)
    request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
    request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw SharingError.networkError
    }
    
    print("📋 Fetch sharing requests response: \(httpResponse.statusCode)")
    
    if let responseString = String(data: data, encoding: .utf8) {
        print("📄 Sharing requests data: \(responseString)")
    }
    
    if httpResponse.statusCode == 200 {
        // Parse the response manually to handle the JSON permissions
        guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            print("❌ Failed to parse JSON array")
            return []
        }
        
        var sharingRequests: [SharingRequest] = []
        
        for requestDict in jsonArray {
            do {
                // Extract basic fields
                guard let idString = requestDict["id"] as? String,
                      let id = UUID(uuidString: idString),
                      let shareId = requestDict["share_id"] as? String,
                      let fromUserId = requestDict["from_user_id"] as? String,
                      let fromUsername = requestDict["from_username"] as? String,
                      let toUserId = requestDict["to_user_id"] as? String,
                      let albumIdString = requestDict["album_id"] as? String,
                      let albumId = UUID(uuidString: albumIdString),
                      let albumTitle = requestDict["album_title"] as? String,
                      let albumArtist = requestDict["album_artist"] as? String,
                      let songCount = requestDict["song_count"] as? Int,
                      let isRead = requestDict["is_read"] as? Bool,
                      let statusString = requestDict["status"] as? String,
                      let status = SharingRequestStatus(rawValue: statusString) else {
                    print("⚠️ Failed to parse basic fields for sharing request")
                    continue
                }
                
                // Parse date
                var createdAt = Date()
                if let createdAtString = requestDict["created_at"] as? String {
                    createdAt = ISO8601DateFormatter().date(from: createdAtString) ?? Date()
                }
                
                // Parse permissions from JSON string
                var permissions = SharePermissions(canListen: true, canDownload: false)
                if let permissionsString = requestDict["permissions"] as? String,
                   let permissionsData = permissionsString.data(using: .utf8),
                   let permissionsDict = try? JSONSerialization.jsonObject(with: permissionsData) as? [String: Any] {
                    
                    let canListen = permissionsDict["can_listen"] as? Bool ?? true
                    let canDownload = permissionsDict["can_download"] as? Bool ?? false
                    
                    var expiresAt: Date? = nil
                    if let expiresAtString = permissionsDict["expires_at"] as? String {
                        expiresAt = ISO8601DateFormatter().date(from: expiresAtString)
                    }
                    
                    permissions = SharePermissions(
                        canListen: canListen,
                        canDownload: canDownload,
                        expiresAt: expiresAt
                    )
                }
                
                // Create SharingRequest
                let sharingRequest = SharingRequest(
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
                    createdAt: createdAt,
                    isRead: isRead,
                    status: status
                )
                
                sharingRequests.append(sharingRequest)
                print("✅ Parsed sharing request: \(albumTitle) from @\(fromUsername)")
                
            } catch {
                print("❌ Failed to parse sharing request: \(error)")
                continue
            }
        }
        
        print("✅ Fetched \(sharingRequests.count) pending sharing requests")
        return sharingRequests
        
    } else {
        let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        print("❌ Failed to fetch sharing requests: \(errorMessage)")
        throw SharingError.fetchFailed
    }
}

func approveSharingRequest(_ request: SharingRequest) async throws {
    print("✅ Approving sharing request: \(request.shareId)")
    
    let supabaseURL = "https://auzsunnwanzljiwdpzov.supabase.co"
    let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1enN1bm53YW56bGppd2Rwem92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIxMzIyNjksImV4cCI6MjA2NzcwODI2OX0.UmuoVT-7uXq5SMFr9duiurbE52Oe865w4ghYPkFwexE"
    
    // Update the request status to approved
    let endpoint = "\(supabaseURL)/rest/v1/sharing_requests?id=eq.\(request.id.uuidString)"
    guard let url = URL(string: endpoint) else {
        throw SharingError.invalidRequest
    }
    
    let updateData: [String: Any] = [
        "status": "approved",
        "is_read": true
    ]
    
    var updateRequest = URLRequest(url: url)
    updateRequest.httpMethod = "PATCH"
    updateRequest.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
    updateRequest.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
    updateRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    updateRequest.httpBody = try JSONSerialization.data(withJSONObject: updateData)
    
    let (data, response) = try await URLSession.shared.data(for: updateRequest)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw SharingError.networkError
    }
    
    if httpResponse.statusCode == 204 {
        print("✅ Sharing request approved successfully")
    } else {
        let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        print("❌ Failed to approve sharing request: \(errorMessage)")
        throw SharingError.creationFailed
    }
}

func rejectSharingRequest(_ request: SharingRequest) async throws {
    print("❌ Rejecting sharing request: \(request.shareId)")
    
    let supabaseURL = "https://auzsunnwanzljiwdpzov.supabase.co"
    let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1enN1bm53YW56bGppd2Rwem92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIxMzIyNjksImV4cCI6MjA2NzcwODI2OX0.UmuoVT-7uXq5SMFr9duiurbE52Oe865w4ghYPkFwexE"
    
    // Update the request status to rejected
    let endpoint = "\(supabaseURL)/rest/v1/sharing_requests?id=eq.\(request.id.uuidString)"
    guard let url = URL(string: endpoint) else {
        throw SharingError.invalidRequest
    }
    
    let updateData: [String: Any] = [
        "status": "rejected",
        "is_read": true
    ]
    
    var updateRequest = URLRequest(url: url)
    updateRequest.httpMethod = "PATCH"
    updateRequest.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
    updateRequest.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
    updateRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    updateRequest.httpBody = try JSONSerialization.data(withJSONObject: updateData)
    
    let (data, response) = try await URLSession.shared.data(for: updateRequest)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw SharingError.networkError
    }
    
    if httpResponse.statusCode == 204 {
        print("✅ Sharing request rejected successfully")
    } else {
        let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        print("❌ Failed to reject sharing request: \(errorMessage)")
        throw SharingError.creationFailed
    }
}

func markRequestAsRead(_ requestId: UUID) async throws {
    print("👁️ Marking request as read: \(requestId)")
    
    let supabaseURL = "https://auzsunnwanzljiwdpzov.supabase.co"
    let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1enN1bm53YW56bGppd2Rwem92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIxMzIyNjksImV4cCI6MjA2NzcwODI2OX0.UmuoVT-7uXq5SMFr9duiurbE52Oe865w4ghYPkFwexE"
    
    let endpoint = "\(supabaseURL)/rest/v1/sharing_requests?id=eq.\(requestId.uuidString)"
    guard let url = URL(string: endpoint) else {
        throw SharingError.invalidRequest
    }
    
    let updateData: [String: Any] = [
        "is_read": true
    ]
    
    var updateRequest = URLRequest(url: url)
    updateRequest.httpMethod = "PATCH"
    updateRequest.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
    updateRequest.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
    updateRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    updateRequest.httpBody = try JSONSerialization.data(withJSONObject: updateData)
    
    let (_, response) = try await URLSession.shared.data(for: updateRequest)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw SharingError.networkError
    }
    
    if httpResponse.statusCode == 204 {
        print("✅ Request marked as read")
    } else {
        print("❌ Failed to mark request as read")
        throw SharingError.creationFailed
    }
}
